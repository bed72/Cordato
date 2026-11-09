package pocketbase

import (
	"os"
	"path/filepath"
	"testing"
)

func BackendRoot(t *testing.T) string {
	t.Helper()
	directory, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	for {
		_, moduleErr := os.Stat(filepath.Join(directory, "go.mod"))
		migrations, migrationsErr := os.Stat(filepath.Join(directory, "pb_migrations"))
		if moduleErr == nil && migrationsErr == nil && migrations.IsDir() {
			return directory
		}
		parent := filepath.Dir(directory)
		if parent == directory {
			t.Fatal("raiz do backend não encontrada")
		}
		directory = parent
	}
}
