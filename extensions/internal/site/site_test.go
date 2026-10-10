package site

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestVersion(t *testing.T) {
	for in, want := range map[string]string{" 6.12.3.foo\n": "6.12.3", "6.1.": "6.1", "": "", "6..3.4": "6..3"} {
		if got := Version(in); got != want {
			t.Fatalf("%q=%q !=%q", in, got, want)
		}
	}
}

func TestInitialSyntaxDiagnostic(t *testing.T) {
	// Source-derived fragment/position rules, in addition to the observed corpus
	// case. These use different state bytes so the diagnostic cannot be a fixture
	// text substitution. Other parser error classes are deliberately not mapped.
	for _, c := range []struct{ input, want string }{
		{"wrong payload", "unexpected character: 'wrong' at line 1 column 1"},
		{" \n\tbroken\tmore", "unexpected character: 'broken' at line 2 column 2"},
		{strings.Repeat("x", 40), "unexpected character: '" + strings.Repeat("x", 32) + "' at line 1 column 1"},
	} {
		p := filepath.Join(t.TempDir(), "kernels.json")
		if err := os.WriteFile(p, []byte(c.input), 0600); err != nil {
			t.Fatal(err)
		}
		_, err := readMap(p)
		if err == nil || err.Error() != c.want {
			t.Fatal(c.input, err, c.want)
		}
		b, err := os.ReadFile(p)
		if err != nil || string(b) != c.input {
			t.Fatal("corrupt state changed", string(b), err)
		}
	}
	for _, input := range []string{"truX", "1e?", `"unterminated`, "", `{"x":}`} {
		p := filepath.Join(t.TempDir(), "kernels.json")
		if err := os.WriteFile(p, []byte(input), 0600); err != nil {
			t.Fatal(err)
		}
		_, err := readMap(p)
		if err == nil || strings.HasPrefix(err.Error(), "unexpected character:") {
			t.Fatal("unverified syntax class was presented as Ruby parity", input, err)
		}
	}
}
func TestOrderedStatePreservesUnselected(t *testing.T) {
	p := filepath.Join(t.TempDir(), "kernels.json")
	_ = os.WriteFile(p, []byte(`{"z":"old","keep":{"custom":true},"a":"delete"}`), 0600)
	m, e := readMap(p)
	if e != nil {
		t.Fatal(e)
	}
	m.set("z", "6.1.2")
	m.del("a")
	m.set("new", "6.2.3")
	if e = m.write(p); e != nil {
		t.Fatal(e)
	}
	b, _ := os.ReadFile(p)
	if !bytes.Contains(b, []byte(`"keep": {`)) || bytes.Index(b, []byte(`"z"`)) > bytes.Index(b, []byte(`"keep"`)) || bytes.Contains(b, []byte(`"a"`)) {
		t.Fatal(string(b))
	}
}
func TestMissingAndCorruptState(t *testing.T) {
	p := filepath.Join(t.TempDir(), "state")
	m, e := readMap(p)
	if e != nil || len(m.keys) != 0 {
		t.Fatal(m, e)
	}
	for _, b := range []string{"bad", "[]", "null", "{} trailing"} {
		_ = os.WriteFile(p, []byte(b), 0600)
		if _, e = readMap(p); e == nil {
			t.Fatalf("accepted %s", b)
		}
		got, _ := os.ReadFile(p)
		if string(got) != b {
			t.Fatal("mutated corrupt state")
		}
	}
}
