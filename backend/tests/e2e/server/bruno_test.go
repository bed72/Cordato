package server_test

import (
	"context"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
)

func runBrunoContract(t *testing.T, sourceDir, baseURL, email string) {
	t.Helper()
	audioFile := filepath.Join(t.TempDir(), "synthetic.m4a")
	if err := os.WriteFile(audioFile, []byte("synthetic-not-m4a"), 0600); err != nil {
		t.Fatal(err)
	}
	runBrunoRequests(t, sourceDir, baseURL, email, audioFile)
	t.Log("as duas requests Bruno passaram por HTTP real em loopback: login e upload binário")
}

func runBrunoRequests(t *testing.T, sourceDir, baseURL, email, audioFile string) {
	t.Helper()
	if _, err := exec.LookPath("bru"); err != nil {
		t.Fatal("CLI Bruno instalada é obrigatória para CORDATO_BRUNO_SMOKE=1")
	}
	runContext, cancel := context.WithTimeout(t.Context(), 90*time.Second)
	defer cancel()
	reportFile := filepath.Join(t.TempDir(), "bruno.json")
	command := exec.CommandContext(runContext, "node", "tool/run_bruno_upload.cjs",
		"--env-var", "baseUrl="+baseURL, "--reporter-json", reportFile)
	command.Dir = sourceDir
	command.Env = append(os.Environ(),
		"CORDATO_DEVELOPMENT_EMAIL="+email,
		"CORDATO_DEVELOPMENT_PASSWORD=Cordato123")
	command.Env = append(command.Env, "CORDATO_DEVELOPMENT_AUDIO_FILE="+audioFile)
	commandError := command.Run()
	report, err := os.ReadFile(reportFile)
	if err != nil {
		t.Fatal("CLI Bruno não gerou relatório sanitizado")
	}
	iterations := []struct {
		Results []struct {
			Path        string
			Skipped     bool
			Response    struct{ Status any }
			TestResults []struct{ Status string }
		}
	}{}
	if err := json.Unmarshal(report, &iterations); err != nil {
		t.Fatal("relatório Bruno inválido")
	}
	executed := 0
	for _, iteration := range iterations {
		for _, request := range iteration.Results {
			status, hasHTTPStatus := request.Response.Status.(float64)
			if request.Skipped || !hasHTTPStatus || len(request.TestResults) == 0 {
				t.Errorf("requisição não exercitada: %s", request.Path)
				continue
			}
			for _, check := range request.TestResults {
				if check.Status != "pass" {
					t.Errorf("asserção Bruno falhou em %s, HTTP %d", request.Path, int(status))
				}
			}
			executed++
		}
	}
	if commandError != nil || executed != 2 {
		t.Fatalf("CLI Bruno: %d/2 requisições exercitadas; erro: %v; detalhes privados omitidos", executed, commandError)
	}
}
