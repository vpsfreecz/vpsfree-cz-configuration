package site

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"sync"
	"testing"
	"time"

	ext "github.com/vpsfreecz/confctl/extension"
)

var siteServices = []string{"machines.select", "exec.run", "ui.write", "ui.machines", "ui.table", "ui.confirm", "format.nix"}

// Run the actual handlers and public SDK in a child with the production FD3/4
// topology. The parent supplies only finite public services, without core code.
func TestSiteProtocolHelper(t *testing.T) {
	if os.Getenv("CONFCTL_SITE_PROTOCOL_HELPER") == "1" {
		ext.Serve(Handlers(), siteServices)
	}
}

type serviceCall struct {
	Method string
	Params json.RawMessage
}

type fixtureReply struct {
	Result ext.ExecResult
	Error  error
	Delay  time.Duration
}

type serviceFixture struct {
	Snapshot ext.Snapshot
	Replies  map[string]fixtureReply
	Accepted bool
	NixNames []string
	NixText  string
	mu       sync.Mutex
	calls    []serviceCall
}

func (f *serviceFixture) handle(ctx context.Context, method string, params json.RawMessage) (any, error) {
	f.mu.Lock()
	f.calls = append(f.calls, serviceCall{method, append(json.RawMessage(nil), params...)})
	f.mu.Unlock()
	switch method {
	case "machines.select":
		return f.Snapshot, nil
	case "exec.run":
		var request struct {
			Snapshot string   `json:"snapshot"`
			Machine  string   `json:"machine"`
			Argv     []string `json:"argv"`
		}
		if err := json.Unmarshal(params, &request); err != nil {
			return nil, err
		}
		if request.Snapshot != f.Snapshot.ID || !reflect.DeepEqual(request.Argv, []string{"uname", "-r"}) {
			return nil, fmt.Errorf("unexpected execution request: %s", params)
		}
		reply, ok := f.Replies[request.Machine]
		if !ok {
			return nil, fmt.Errorf("unexpected execution on %s", request.Machine)
		}
		if reply.Delay != 0 {
			timer := time.NewTimer(reply.Delay)
			defer timer.Stop()
			select {
			case <-timer.C:
			case <-ctx.Done():
				return nil, ctx.Err()
			}
		}
		return reply.Result, reply.Error
	case "ui.write", "ui.machines", "ui.table":
		return map[string]any{}, nil
	case "ui.confirm":
		return map[string]any{"accepted": f.Accepted}, nil
	case "format.nix":
		var request struct {
			Value []string `json:"value"`
		}
		if err := json.Unmarshal(params, &request); err != nil {
			return nil, err
		}
		if !reflect.DeepEqual(request.Value, f.NixNames) {
			return nil, fmt.Errorf("unexpected netboot order/selection: %q", request.Value)
		}
		return map[string]any{"text": f.NixText}, nil
	default:
		return nil, fmt.Errorf("unexpected service %s", method)
	}
}

func (f *serviceFixture) requests(method string) []json.RawMessage {
	f.mu.Lock()
	defer f.mu.Unlock()
	var out []json.RawMessage
	for _, call := range f.calls {
		if call.Method == method {
			out = append(out, call.Params)
		}
	}
	return out
}

func runSiteProtocol(t *testing.T, f *serviceFixture, handler string, in ext.Invocation) (int, error) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	childRead, parentWrite, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	defer parentWrite.Close()
	parentRead, childWrite, err := os.Pipe()
	if err != nil {
		childRead.Close()
		t.Fatal(err)
	}
	defer parentRead.Close()
	cmd := exec.CommandContext(ctx, os.Args[0], "-test.run=^TestSiteProtocolHelper$")
	cmd.Dir = in.Root
	cmd.Env = append(cmd.Environ(), "CONFCTL_SITE_PROTOCOL_HELPER=1")
	cmd.ExtraFiles = []*os.File{childRead, childWrite}
	cmd.WaitDelay = time.Second
	var stdout, stderr bytes.Buffer
	cmd.Stdout, cmd.Stderr = &stdout, &stderr
	err = cmd.Start()
	childRead.Close()
	childWrite.Close()
	if err != nil {
		t.Fatal(err)
	}
	waited := false
	defer func() {
		cancel()
		if !waited {
			_ = cmd.Process.Kill()
			_ = cmd.Wait()
		}
	}()
	peer := ext.NewPeer(ctx, parentRead, parentWrite, "fixture")
	peer.SetHandler(f.handle)
	defer func() {
		cancel()
		parentRead.Close()
		parentWrite.Close()
		peer.WaitHandlers()
	}()
	var initialized ext.InitResult
	if err = peer.Call(ctx, "initialize", ext.Init{Protocol: ext.Version{Major: 1}, ExtensionID: "test.site", Supported: siteServices}, &initialized); err != nil {
		t.Fatal("initialize", err)
	}
	if initialized.Protocol.Major != 1 || !reflect.DeepEqual(initialized.Required, siteServices) {
		t.Fatal("unexpected public service contract", initialized)
	}
	var result ext.RunResult
	runErr := peer.Call(ctx, "run", ext.Run{Handler: handler, Context: in}, &result)
	waitErr := cmd.Wait()
	waited = true
	if ctx.Err() != nil {
		t.Fatal("protocol test deadline", ctx.Err(), stdout.String(), stderr.String())
	}
	code := cmd.ProcessState.ExitCode()
	if code < 0 || (waitErr != nil && code == 0) || stdout.Len() != 0 || stderr.Len() != 0 {
		t.Fatal("unexpected child process/stdio result", code, waitErr, stdout.String(), stderr.String())
	}
	if runErr == nil && (code != 0 || result.ExitCode != 0) {
		t.Fatal("successful run/child exit disagree", result, code)
	}
	if runErr != nil && code != 1 {
		t.Fatal("failed run/child exit disagree", runErr, code)
	}
	return code, runErr
}

func kernelState(t *testing.T, root string, initial *string) string {
	t.Helper()
	path := filepath.Join(root, "configs/node/kernels.json")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	if initial != nil {
		if err := os.WriteFile(path, []byte(*initial), 0600); err != nil {
			t.Fatal(err)
		}
	}
	return path
}

func readState(t *testing.T, path string) string {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

func kernelRows(t *testing.T, f *serviceFixture) []map[string]string {
	t.Helper()
	requests := f.requests("ui.table")
	if len(requests) != 1 {
		t.Fatal("missing or duplicate table", requests)
	}
	var request struct {
		Columns []map[string]any    `json:"columns"`
		Rows    []map[string]string `json:"rows"`
		Header  bool                `json:"header"`
	}
	if err := json.Unmarshal(requests[0], &request); err != nil {
		t.Fatal(err)
	}
	if !request.Header || len(request.Columns) != 2 || request.Columns[0]["key"] != "host" || request.Columns[0]["min_width"] != float64(50) || request.Columns[1]["key"] != "kernel" {
		t.Fatal("changed kernel table contract", request)
	}
	return request.Rows
}

func writeTexts(t *testing.T, f *serviceFixture) []string {
	t.Helper()
	var texts []string
	for _, raw := range f.requests("ui.write") {
		var request struct {
			Stream string `json:"stream"`
			Text   string `json:"text"`
		}
		if err := json.Unmarshal(raw, &request); err != nil || request.Stream != "stdout" {
			t.Fatal("unexpected UI write", string(raw), err)
		}
		texts = append(texts, request.Text)
	}
	return texts
}

func TestNetbootPublicProtocolOrderAndCarriedExclusion(t *testing.T) {
	root := t.TempDir()
	if err := os.Mkdir(filepath.Join(root, "cluster"), 0700); err != nil {
		t.Fatal(err)
	}
	carrier := "carrier"
	f := &serviceFixture{Snapshot: ext.Snapshot{ID: "netboot", Machines: []ext.Machine{
		{Name: "z/first", Attributes: map[string]any{"netboot": map[string]any{"enable": true}}},
		{Name: "carried", CarrierName: &carrier, Attributes: map[string]any{"netboot": map[string]any{"enable": true}}},
		{Name: "disabled", Attributes: map[string]any{"netboot": map[string]any{"enable": false}}},
		{Name: "a/last", Attributes: map[string]any{"netboot": map[string]any{"enable": json.Number("0")}}},
	}}, NixNames: []string{"z/first", "a/last"}, NixText: "[\n  \"z/first\"\n  \"a/last\"\n]"}
	code, err := runSiteProtocol(t, f, "netboot.rediscover", ext.Invocation{Root: root, Event: "rediscover.after-write"})
	if code != 0 || err != nil {
		t.Fatal(code, err)
	}
	want := "# This file is auto-generated on confctl rediscover, changes will be lost\n" + f.NixText + "\n"
	if got := readState(t, filepath.Join(root, "cluster/netbootable.nix")); got != want {
		t.Fatal(got, want)
	}
	var selection ext.Selection
	requests := f.requests("machines.select")
	if len(requests) != 1 || json.Unmarshal(requests[0], &selection) != nil || !selection.Refresh || selection.Managed != "all" {
		t.Fatal("netboot needs fresh full inventory", requests)
	}
	if !reflect.DeepEqual(writeTexts(t, f), []string{"replace cluster/netbootable.nix\n"}) || len(f.requests("exec.run")) != 0 {
		t.Fatal("unexpected netboot effects", f.calls)
	}
}

func TestKernelsPublicProtocolErrorSentinelAndStateOrder(t *testing.T) {
	root := t.TempDir()
	initial := `{"keep":{"custom":true},"prior":"old"}`
	path := kernelState(t, root, &initial)
	carrier := "carrier"
	f := &serviceFixture{Snapshot: ext.Snapshot{ID: "kernels", Machines: []ext.Machine{
		{Name: "prior", Spin: "vpsadminos"}, {Name: "absent", Spin: "vpsadminos"}, {Name: "carried", Spin: "vpsadminos", CarrierName: &carrier},
	}}, Replies: map[string]fixtureReply{
		"prior":   {Result: ext.ExecResult{Stdout: []byte("error\n")}},
		"absent":  {Result: ext.ExecResult{Stdout: []byte("error.\n")}},
		"carried": {Result: ext.ExecResult{Stdout: []byte("6.12.35.extra\n")}},
	}}
	code, err := runSiteProtocol(t, f, "runtime.update", ext.Invocation{Root: root, Options: map[string]any{"yes": true}})
	if code != 0 || err != nil {
		t.Fatal(code, err)
	}
	want := "{\n  \"keep\": {\n    \"custom\": true\n  },\n  \"prior\": \"old\",\n  \"carried\": \"6.12.35\"\n}"
	if got := readState(t, path); got != want {
		t.Fatal(got, want)
	}
	if !reflect.DeepEqual(kernelRows(t, f), []map[string]string{{"host": "prior", "kernel": "error"}, {"host": "absent", "kernel": "error"}, {"host": "carried", "kernel": "6.12.35"}}) || len(f.requests("exec.run")) != 3 || len(f.requests("ui.confirm")) != 0 || len(writeTexts(t, f)) != 0 {
		t.Fatal("manual selection/table changed", f.calls)
	}
}

func TestKernelsPublicProtocolFailureDetailsCompletionOrder(t *testing.T) {
	root := t.TempDir()
	initial := `{"keep":"unchanged","slow":"old","fast":"old"}`
	path := kernelState(t, root, &initial)
	f := &serviceFixture{Snapshot: ext.Snapshot{ID: "failures", Machines: []ext.Machine{{Name: "slow", Spin: "vpsadminos"}, {Name: "fast", Spin: "vpsadminos"}, {Name: "good", Spin: "vpsadminos"}}}, Replies: map[string]fixtureReply{
		"slow": {Result: ext.ExecResult{Command: "slow command", ExitCode: 12, Stderr: []byte("slow failure\n")}, Delay: 400 * time.Millisecond},
		"fast": {Result: ext.ExecResult{Command: "fast command", ExitCode: 13, Stderr: []byte("fast failure\n")}},
		"good": {Result: ext.ExecResult{Stdout: []byte("6.12.35.extra\n")}},
	}}
	code, err := runSiteProtocol(t, f, "runtime.update", ext.Invocation{Root: root, Options: map[string]any{"yes": true}})
	if code != 0 || err != nil {
		t.Fatal(code, err)
	}
	if got := readState(t, path); got != "{\n  \"keep\": \"unchanged\",\n  \"good\": \"6.12.35\"\n}" {
		t.Fatal("failed selected keys not removed or unselected state lost", got)
	}
	rows := kernelRows(t, f)
	if len(rows) != 3 || rows[0]["host"] != "slow" || rows[1]["host"] != "fast" || rows[2]["kernel"] != "6.12.35" {
		t.Fatal("main table lost inventory order", rows)
	}
	want := []string{"\n", "Error on fast: Running `fast command` failed with\n  exit status: 13\n  stdout: Nothing written\n  stderr: fast failure\n\n", "Error on slow: Running `slow command` failed with\n  exit status: 12\n  stdout: Nothing written\n  stderr: slow failure\n\n"}
	if got := writeTexts(t, f); !reflect.DeepEqual(got, want) {
		t.Fatal("failure details lost completion order", got, want)
	}
}

func TestKernelsPublicProtocolHookFiltersAndEmptySelection(t *testing.T) {
	for _, empty := range []bool{false, true} {
		t.Run(fmt.Sprintf("empty=%t", empty), func(t *testing.T) {
			root := t.TempDir()
			initial := `{"keep":"unchanged","carried":"prior"}`
			path := kernelState(t, root, &initial)
			carrier := "carrier"
			machines := []ext.Machine{{Name: "carried", Spin: "vpsadminos", CarrierName: &carrier}, {Name: "nixos", Spin: "nixos"}}
			if !empty {
				machines = append(machines, ext.Machine{Name: "node", Spin: "vpsadminos"})
			}
			f := &serviceFixture{Snapshot: ext.Snapshot{ID: "prepare", Machines: machines}, Replies: map[string]fixtureReply{"node": {Result: ext.ExecResult{Stdout: []byte("6.12.35\n")}}}}
			code, err := runSiteProtocol(t, f, "runtime.prepare", ext.Invocation{Root: root, Event: "deploy.prepare", SelectedNames: []string{"carried", "nixos", "node"}})
			if code != 0 || err != nil || len(f.requests("ui.confirm")) != 0 {
				t.Fatal(code, err, f.calls)
			}
			if empty {
				if readState(t, path) != initial || len(f.requests("exec.run")) != 0 || len(f.requests("ui.table")) != 0 || len(writeTexts(t, f)) != 0 {
					t.Fatal("empty hook changed state or UI", f.calls)
				}
			} else {
				if !reflect.DeepEqual(kernelRows(t, f), []map[string]string{{"host": "node", "kernel": "6.12.35"}}) || !reflect.DeepEqual(writeTexts(t, f), []string{"Updating runtime kernel information...\n", "\n"}) || readState(t, path) != "{\n  \"keep\": \"unchanged\",\n  \"carried\": \"prior\",\n  \"node\": \"6.12.35\"\n}" {
					t.Fatal("hook filter/output/state changed", f.calls, readState(t, path))
				}
			}
		})
	}
}

func TestKernelsPublicProtocolMissingEmptyAndCorruptState(t *testing.T) {
	for _, corrupt := range []bool{false, true} {
		t.Run(fmt.Sprintf("corrupt=%t", corrupt), func(t *testing.T) {
			root := t.TempDir()
			var initial *string
			if corrupt {
				text := "bad json"
				initial = &text
			}
			path := kernelState(t, root, initial)
			f := &serviceFixture{Snapshot: ext.Snapshot{ID: "empty", Machines: []ext.Machine{}}}
			code, err := runSiteProtocol(t, f, "runtime.update", ext.Invocation{Root: root, Options: map[string]any{"yes": true}})
			if corrupt {
				if code != 1 || err == nil || err.Error() != "unexpected character: 'bad' at line 1 column 1" || readState(t, path) != *initial || len(f.requests("ui.table")) != 0 {
					t.Fatal("corrupt state changed or error swallowed", code, err, f.calls)
				}
			} else if code != 0 || err != nil || readState(t, path) != "{}" || len(kernelRows(t, f)) != 0 {
				t.Fatal("manual empty selection/missing state failed", code, err, f.calls)
			}
			if len(f.requests("exec.run")) != 0 {
				t.Fatal("unexpected empty/corrupt execution", f.calls)
			}
		})
	}
}

func TestKernelsPublicProtocolConfirmationAndCancellationNoSave(t *testing.T) {
	for _, canceled := range []bool{false, true} {
		t.Run(fmt.Sprintf("canceled=%t", canceled), func(t *testing.T) {
			root := t.TempDir()
			initial := `{"node":"old","keep":"unchanged"}`
			path := kernelState(t, root, &initial)
			f := &serviceFixture{Snapshot: ext.Snapshot{ID: "no-save", Machines: []ext.Machine{{Name: "node", Spin: "vpsadminos"}}}, Replies: map[string]fixtureReply{"node": {Error: context.Canceled}}}
			attrs, tags := []string{"spin=vpsadminos"}, []string{"staging"}
			code, err := runSiteProtocol(t, f, "runtime.update", ext.Invocation{Root: root, Options: map[string]any{"yes": canceled, "attr": attrs, "tag": tags}, Arguments: []string{"node"}})
			want := "Aborted"
			if canceled {
				want = "invocation canceled: context canceled"
			}
			if code != 1 || err == nil || err.Error() != want || readState(t, path) != initial || len(f.requests("ui.table")) != 0 {
				t.Fatal("invocation failure saved state", code, err, f.calls)
			}
			if canceled {
				if len(f.requests("exec.run")) != 1 || len(f.requests("ui.confirm")) != 0 {
					t.Fatal("cancellation path not exercised", f.calls)
				}
			} else if len(f.requests("exec.run")) != 0 || len(f.requests("ui.confirm")) != 1 || len(f.requests("ui.machines")) != 1 || !reflect.DeepEqual(writeTexts(t, f), []string{"The following machines will be queried:\n"}) {
				t.Fatal("confirmation path not exercised", f.calls)
			}
			var selection ext.Selection
			if err := json.Unmarshal(f.requests("machines.select")[0], &selection); err != nil || selection.Pattern == nil || *selection.Pattern != "node" || !reflect.DeepEqual(selection.Attrs, attrs) || !reflect.DeepEqual(selection.Tags, tags) || selection.Managed != "all" {
				t.Fatal("lost manual selection", selection, err)
			}
		})
	}
}
