package bootstrap_test

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"cordato/backend/internal/bootstrap"

	pb "ganigeorgiev.com/pocketbase/pocketbase"
)

func TestHelpAndVersionDoNotBootstrap(t *testing.T) {
	for _, scenario := range []struct {
		name string
		args []string
		text string
	}{
		{"help", []string{"--help"}, "migrate"},
		{"serve-help", []string{"serve", "--help"}, "--http"},
		{"migrate-help", []string{"migrate", "--help"}, "history-sync"},
		{"version", []string{"--version"}, "cordato (PocketBase 0.41.1)"},
	} {
		t.Run(scenario.name, func(t *testing.T) {
			t.Chdir(t.TempDir())
			t.Setenv("POCKETBASE_ENCRYPTION_KEY", "")
			previousArgs := os.Args
			os.Args = append([]string{"cordato"}, scenario.args...)
			t.Cleanup(func() { os.Args = previousArgs })

			app, err := bootstrap.New(pb.Config{})
			if err != nil {
				t.Fatal(err)
			}
			output := &bytes.Buffer{}
			app.RootCmd.SetOut(output)
			if err := app.Start(); err != nil {
				t.Fatal(err)
			}
			if !strings.Contains(output.String(), scenario.text) {
				t.Fatal("saída de ajuda/versão inesperada")
			}
			if app.IsBootstrapped() {
				t.Fatal("ajuda/versão não deve inicializar o banco")
			}
			if _, err := os.Stat(filepath.Join(app.DataDir(), "data.db")); !os.IsNotExist(err) {
				t.Fatal("ajuda/versão não deve criar banco")
			}
		})
	}
}
