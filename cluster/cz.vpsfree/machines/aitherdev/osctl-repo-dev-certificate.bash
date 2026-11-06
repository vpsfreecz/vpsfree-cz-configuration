# Called by the site oneshots. The existing CA is read, never created/rotated.
set -euo pipefail
umask 077

if [ "$#" -ne 7 ]; then
  echo 'usage: reconcile CA_DIRECTORY TLS_DIRECTORY LOCK_FILE GROUP HOST DAYS RENEW_SECONDS' >&2
  exit 2
fi
ca_directory=$1
tls_directory=$2
lock_file=$3
group=$4
host=$5
valid_days=$6
renew_seconds=$7
authority="$ca_directory/authority"
ca_cert="$authority/ca.pem"
ca_key="$authority/ca-key.pem"
owner=$(id -u)
group_id=$(getent group "$group" | cut -d: -f3)
if [ -z "$group_id" ] || ! [[ "$host" =~ ^[a-z0-9]+([.-][a-z0-9]+)+$ ]] ||
   ! [[ "$valid_days" =~ ^[1-9][0-9]*$ ]] || ! [[ "$renew_seconds" =~ ^[1-9][0-9]*$ ]]; then
  echo 'invalid certificate configuration' >&2
  exit 2
fi

assert_directory() {
  if [ -L "$1" ] || { [ -e "$1" ] && [ ! -d "$1" ]; }; then
    echo "certificate path must be a real directory: $1" >&2
    exit 1
  fi
}
assert_regular() {
  if [ -L "$1" ] || { [ -e "$1" ] && [ ! -f "$1" ]; }; then
    echo "certificate path must be a regular file: $1" >&2
    exit 1
  fi
}

assert_directory "$(dirname "$lock_file")"
assert_regular "$lock_file"
exec 9<>"$lock_file"
flock -w 30 9
if [ "$(stat -c '%u' "$lock_file")" != "$owner" ]; then
  echo 'substrate lock has the wrong owner' >&2
  exit 1
fi
chmod 0600 "$lock_file"

assert_directory "$ca_directory"
assert_directory "$authority"
for file in "$ca_cert" "$ca_key"; do
  assert_regular "$file"
  if [ ! -f "$file" ] || [ "$(stat -c '%u' "$file")" != "$owner" ]; then
    echo 'existing workspace CA is missing or has the wrong owner' >&2
    exit 1
  fi
done
if [ "$(stat -c '%a' "$ca_key")" != 600 ]; then
  echo 'existing workspace CA key permissions are unsafe' >&2
  exit 1
fi
openssl verify -no-CApath -no-CAstore -CAfile "$ca_cert" "$ca_cert" >/dev/null
openssl x509 -checkend "$renew_seconds" -noout -in "$ca_cert" >/dev/null
ca_public=$(openssl x509 -in "$ca_cert" -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256)
key_public=$(openssl pkey -in "$ca_key" -pubout -outform DER | openssl dgst -sha256)
if [ "$ca_public" != "$key_public" ]; then
  echo 'existing workspace CA certificate and key differ' >&2
  exit 1
fi

assert_directory "$(dirname "$tls_directory")"
assert_directory "$tls_directory"
assert_directory "$tls_directory/pairs"
install -d -m 0750 -g "$group" "$tls_directory" "$tls_directory/pairs"

pair_valid() {
  local candidate=$1 cert key names cert_public key_public
  cert="$candidate/server.pem"
  key="$candidate/server-key.pem"
  [ ! -L "$candidate" ] && [ -d "$candidate" ] &&
    [ "$(stat -c '%u:%g:%a' "$candidate")" = "$owner:$group_id:750" ] &&
    [ ! -L "$cert" ] && [ -f "$cert" ] &&
    [ "$(stat -c '%u:%g:%a' "$cert")" = "$owner:$group_id:644" ] &&
    [ ! -L "$key" ] && [ -f "$key" ] &&
    [ "$(stat -c '%u:%g:%a' "$key")" = "$owner:$group_id:640" ] || return 1
  openssl verify -purpose sslserver -verify_hostname "$host" -no-CApath -no-CAstore \
    -CAfile "$ca_cert" "$cert" >/dev/null 2>&1 || return 1
  openssl x509 -checkend "$renew_seconds" -noout -in "$cert" >/dev/null 2>&1 || return 1
  names=$(openssl x509 -noout -ext subjectAltName -in "$cert" | tail -n +2 | tr ',' '\n' | sed 's/^[[:space:]]*//' | LC_ALL=C sort) || return 1
  [ "$names" = "DNS:$host" ] || return 1
  [ "$(openssl x509 -noout -ext basicConstraints -in "$cert" | tail -n +2 | xargs)" = 'CA:FALSE' ] || return 1
  [ "$(openssl x509 -noout -ext keyUsage -in "$cert" | tail -n +2 | xargs)" = 'Digital Signature' ] || return 1
  [ "$(openssl x509 -noout -ext extendedKeyUsage -in "$cert" | tail -n +2 | xargs)" = 'TLS Web Server Authentication' ] || return 1
  cert_public=$(openssl x509 -in "$cert" -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256) || return 1
  key_public=$(openssl pkey -in "$key" -pubout -outform DER | openssl dgst -sha256) || return 1
  [ "$cert_public" = "$key_public" ]
}

current="$tls_directory/current"
if [ -L "$current" ]; then
  target=$(readlink "$current")
  if ! [[ "$target" =~ ^pairs/pair-[0-9]+-[0-9]+-[A-Za-z0-9]+$ ]]; then
    echo 'invalid certificate generation link' >&2
    exit 1
  fi
  if pair_valid "$tls_directory/$target"; then
    echo unchanged
    exit 0
  fi
elif [ -e "$current" ]; then
  echo 'certificate current must be a generation symlink' >&2
  exit 1
fi

build=$(mktemp -d "$tls_directory/.pair.XXXXXX")
trap 'rm -rf -- "$build"; rm -f -- "$tls_directory/.current.$$"' EXIT
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$build/server-key.pem"
openssl req -new -key "$build/server-key.pem" -subj "/CN=$host" -out "$build/request.pem"
cat > "$build/extensions.cnf" <<EOF
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature
extendedKeyUsage=serverAuth
subjectAltName=DNS:$host
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
EOF
serial=$(openssl rand -hex 16)
openssl x509 -req -sha256 -days "$valid_days" -in "$build/request.pem" \
  -CA "$ca_cert" -CAkey "$ca_key" -set_serial "0x$serial" \
  -extfile "$build/extensions.cnf" -out "$build/server.pem"
rm "$build/request.pem" "$build/extensions.cnf"
chgrp "$group" "$build" "$build/server.pem" "$build/server-key.pem"
chmod 0750 "$build"
chmod 0644 "$build/server.pem"
chmod 0640 "$build/server-key.pem"
if ! pair_valid "$build"; then
  echo 'generated certificate failed validation' >&2
  exit 1
fi
pair="pairs/pair-$(date +%s)-$$-$(openssl rand -hex 4)"
mv -T "$build" "$tls_directory/$pair"
ln -s "$pair" "$tls_directory/.current.$$"
mv -Tf "$tls_directory/.current.$$" "$current"
trap - EXIT
echo changed
