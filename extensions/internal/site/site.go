// Package site ports the two pinned configuration handlers through public SDK.
package site

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	ext "github.com/vpsfreecz/confctl/extension"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

func Handlers() map[string]ext.Handler {
	return map[string]ext.Handler{"netboot.rediscover": Rediscover, "runtime.update": func(ctx context.Context, c *ext.Client, in ext.Invocation) error { return Kernels(ctx, c, in, false) }, "runtime.prepare": func(ctx context.Context, c *ext.Client, in ext.Invocation) error { return Kernels(ctx, c, in, true) }}
}
func Rediscover(ctx context.Context, c *ext.Client, in ext.Invocation) error {
	s, e := c.Select(ctx, ext.Selection{Managed: "all", Refresh: true})
	if e != nil {
		return e
	}
	names := []string{}
	for _, m := range s.Machines {
		if v := m.Attr("netboot.enable"); v != nil && v != false && m.CarrierName == nil {
			names = append(names, m.Name)
		}
	}
	text, e := c.Nix(ctx, names)
	if e != nil {
		return e
	}
	if e = c.Write(ctx, "stdout", "replace cluster/netbootable.nix\n", "plain"); e != nil {
		return e
	}
	return os.WriteFile(filepath.Join(in.Root, "cluster/netbootable.nix"), []byte("# This file is auto-generated on confctl rediscover, changes will be lost\n"+text+"\n"), 0666)
}

// orderedMap preserves the original JSON object's key order and unselected
// values. Ruby appends newly selected hosts in inventory order, not map order.
type orderedMap struct {
	keys   []string
	values map[string]json.RawMessage
}

func readMap(path string) (orderedMap, error) {
	o := orderedMap{values: map[string]json.RawMessage{}}
	b, e := os.ReadFile(path)
	if os.IsNotExist(e) {
		return o, nil
	}
	if e != nil {
		return o, e
	}
	d := json.NewDecoder(bytes.NewReader(b))
	t, e := d.Token()
	if e != nil {
		return o, kernelJSONDiagnostic(b, e)
	}
	if t != json.Delim('{') {
		return o, fmt.Errorf("kernel state must be a JSON object")
	}
	for d.More() {
		k, e := d.Token()
		if e != nil {
			return o, e
		}
		var v json.RawMessage
		if e = d.Decode(&v); e != nil {
			return o, e
		}
		key := k.(string)
		if _, ok := o.values[key]; !ok {
			o.keys = append(o.keys, key)
		}
		o.values[key] = v
	}
	_, e = d.Token()
	if e == nil {
		var extra any
		if e = d.Decode(&extra); e == nil {
			e = fmt.Errorf("extra JSON content")
		} else if e == io.EOF {
			e = nil
		}
	}
	return o, e
}

// JSON gem 2.21.2 parser.c: JSON_PHASE_VALUE's default, build_parse_error_message
// and cursor_position. Only the observed initial invalid-value-starter class is
// translated; keyword, number, string, object-key and EOF diagnostics remain U.
func kernelJSONDiagnostic(b []byte, err error) error {
	var syntax *json.SyntaxError
	if !errors.As(err, &syntax) {
		return err
	}
	i := 0
	for i < len(b) && strings.ContainsRune(" \t\r\n", rune(b[i])) {
		i++
	}
	// Decoder.Token skips initial whitespace before its value scanner starts;
	// SyntaxError.Offset for this first invalid byte is therefore token-relative.
	if i == len(b) || syntax.Offset != 1 || !strings.Contains(syntax.Error(), "looking for beginning of value") || b[i] == 0 || strings.ContainsRune("ntfNI-0123456789\"[{", rune(b[i])) {
		return err
	}
	end := i
	for end < len(b) && end-i < 32 && b[end] != 0 && !strings.ContainsRune(" \t\r\n", rune(b[end])) {
		end++
	}
	// The gem removes a final multibyte character from its byte-limited fragment.
	for end > i && b[end-1] >= 0x80 && b[end-1] < 0xc0 {
		end--
	}
	if end > i && b[end-1] >= 0xc0 {
		end--
	}
	line := bytes.Count(b[:i], []byte{'\n'}) + 1
	column := i - bytes.LastIndexByte(b[:i], '\n')
	return fmt.Errorf("unexpected character: '%s' at line %d column %d", b[i:end], line, column)
}
func (o *orderedMap) set(k, v string) {
	if _, ok := o.values[k]; !ok {
		o.keys = append(o.keys, k)
	}
	b, _ := json.Marshal(v)
	o.values[k] = b
}
func (o *orderedMap) del(k string) { delete(o.values, k) }
func (o orderedMap) write(path string) error {
	var b bytes.Buffer
	b.WriteString("{")
	first := true
	for _, k := range o.keys {
		v, ok := o.values[k]
		if !ok {
			continue
		}
		if !first {
			b.WriteString(",")
		}
		b.WriteString("\n  ")
		q, _ := json.Marshal(k)
		b.Write(q)
		b.WriteString(": ")
		var pretty bytes.Buffer
		if e := json.Indent(&pretty, v, "  ", "  "); e != nil {
			return e
		}
		b.Write(pretty.Bytes())
		first = false
	}
	if !first {
		b.WriteByte('\n')
	}
	b.WriteString("}")
	return os.WriteFile(path, b.Bytes(), 0666)
}
func Version(s string) string {
	s = strings.TrimSpace(s)
	parts := strings.Split(s, ".")
	for len(parts) > 0 && parts[len(parts)-1] == "" {
		parts = parts[:len(parts)-1]
	}
	if len(parts) > 3 {
		parts = parts[:3]
	}
	return strings.Join(parts, ".")
}
func Kernels(ctx context.Context, c *ext.Client, in ext.Invocation, hook bool) error {
	s, e := c.Select(ctx, ext.SelectionFrom(in))
	if e != nil {
		return e
	}
	s = s.Filter(func(m ext.Machine) bool { return m.Spin == "vpsadminos" && (!hook || m.CarrierName == nil) })
	if hook && len(s.Machines) == 0 {
		return nil
	}
	if hook {
		if e = c.Write(ctx, "stdout", "Updating runtime kernel information...\n", "bright"); e != nil {
			return e
		}
	} else if in.Options["yes"] != true {
		if e = c.Write(ctx, "stdout", "The following machines will be queried:\n", "plain"); e != nil {
			return e
		}
		if e = c.Machines(ctx, s); e != nil {
			return e
		}
		ok, e := c.Confirm(ctx)
		if e != nil {
			return e
		}
		if !ok {
			return fmt.Errorf("Aborted")
		}
	}
	path := filepath.Join(in.Root, "configs/node/kernels.json")
	saved, e := readMap(path)
	if e != nil {
		return e
	}
	results, e := c.RunMany(ctx, s, []string{"uname", "-r"})
	if e != nil {
		return e
	}
	rows := []map[string]any{}
	failures := []int{}
	for i, m := range s.Machines {
		r := results[i]
		kernel := "error"
		if r.Error == nil && r.Result.ExitCode == 0 && r.Result.Signal == "" {
			kernel = Version(string(r.Result.Stdout))
			if kernel != "error" {
				saved.set(m.Name, kernel)
			}
		} else {
			failures = append(failures, i)
		}
		rows = append(rows, map[string]any{"host": m.Name, "kernel": kernel})
	}
	if e = c.Table(ctx, []map[string]any{{"key": "host", "label": "HOST", "min_width": 50}, {"key": "kernel", "label": "KERNEL"}}, rows); e != nil {
		return e
	}
	if len(failures) > 0 {
		// The main rows retain inventory order; Ruby's worker errors Hash is
		// populated in completion order and controls only these detail blocks.
		sort.Slice(failures, func(i, j int) bool { return results[failures[i]].Completion < results[failures[j]].Completion })
		if e = c.Write(ctx, "stdout", "\n", "plain"); e != nil {
			return e
		}
		for _, i := range failures {
			m := s.Machines[i]
			r := results[i]
			message := ""
			if r.Error != nil {
				message = r.Error.Error()
			} else {
				message = fmt.Sprintf("Running `%s` failed with\n  exit status: %d\n  stdout: %s\n  stderr: %s\n", r.Result.Command, r.Result.ExitCode, errorOutput(r.Result.Stdout), errorOutput(r.Result.Stderr))
			}
			if e = c.Write(ctx, "stdout", fmt.Sprintf("Error on %s: %s\n", m.Name, message), "plain"); e != nil {
				return e
			}
			saved.del(m.Name)
		}
	}
	if e = saved.write(path); e != nil {
		return e
	}
	if hook {
		return c.Write(ctx, "stdout", "\n", "plain")
	}
	return nil
}
func target(m ext.Machine) string {
	if m.Target.Host == nil {
		return ""
	}
	return *m.Target.Host
}

func errorOutput(b []byte) string {
	s := strings.TrimSpace(string(b))
	if s == "" {
		return "Nothing written"
	}
	return s
}
