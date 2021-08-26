NETWORK_ADMINS	=  9B77B16D43CB83ABD662E61A2F592E42D71629C4 # snajpa
NETWORK_ADMINS	+= 98CF7F9A6ACE7AA1E0FCF485AF3CF1838CFCA806 # dante

SWITCHES	= `cat switchlist | awk '{ printf "%s\n", $$2; }'`

RECIPIENTS	= `for admin in $(NETWORK_ADMINS); do echo "--recipient $$admin "; done`

save-running-config:
	@if [ "$(PASS)" != "" ]; then PASS=$(PASS); else stty -echo; read -p 'Enter password: ' PASS; stty echo; fi; \
	for sw in $(SWITCHES); do \
		ip=`cat switchlist | grep $$sw | awk '{ print $$1}'`; \
		echo "enable\n$$PASS\nshow running-config" | ssh -ladmin $$ip > unencrypted/$$sw && \
			sed -i '1,10d' unencrypted/$$sw &&  \
			sed -i '$$ d' unencrypted/$$sw; \
	done || true;

encrypt:
	@for sw in $(SWITCHES); do \
		if [ ! -f unencrypted/$$sw ]; then exit 1; fi; \
		if [ -f $${sw}.asc ]; then rm $${sw}.asc; fi; \
		cat unencrypted/$$sw | gpg --batch --armor --encrypt $(RECIPIENTS) --output $${sw}.asc; \
	done

decrypt:
	@for sw in $(SWITCHES); do \
		if [ ! -f $${sw}.asc ]; then exit 1; fi; \
		if [ -f unencrypted/$$sw ]; then rm unencrypted/$$sw; fi; \
		gpg --batch --decrypt < $${sw}.asc --output unencrypted/$$sw; \
	done
