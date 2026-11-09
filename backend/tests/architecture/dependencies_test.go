package architecture_test

import (
	"go/parser"
	"go/token"
	"io/fs"
	"path/filepath"
	"strconv"
	"strings"
	"testing"

	pbtest "cordato/backend/tests/support/pocketbase"
)

func TestApplicationAndTestIsolation(t *testing.T) {
	applicationFiles := 0
	root := pbtest.BackendRoot(t)
	err := filepath.WalkDir(root, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() && (strings.HasPrefix(entry.Name(), ".") || path == filepath.Join(root, "tests")) {
			return filepath.SkipDir
		}
		if entry.IsDir() || !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
			return nil
		}
		file, err := parser.ParseFile(token.NewFileSet(), path, nil, parser.ImportsOnly)
		if err != nil {
			return err
		}
		relativePath, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		inApplication := strings.HasPrefix(filepath.ToSlash(relativePath), "internal/application/")
		if inApplication {
			applicationFiles++
		}
		for _, imported := range file.Imports {
			dependency, err := strconv.Unquote(imported.Path.Value)
			if err != nil {
				return err
			}
			for _, segment := range strings.Split(dependency, "/") {
				if segment == "tests" || segment == "testing" || segment == "testsupport" || segment == "mocks" || segment == "fakes" || segment == "support" {
					t.Errorf("produção %s importa suporte de teste %s", path, dependency)
				}
			}
			if inApplication {
				first, _, _ := strings.Cut(dependency, "/")
				if strings.Contains(first, ".") || first == "cordato" || first == "net" || first == "database" || first == "os" {
					t.Errorf("application %s importa dependência externa/transporte/persistência %s", path, dependency)
				}
			}
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if applicationFiles == 0 {
		t.Fatal("nenhuma implementação de application verificada")
	}
}

func TestInternalTestsRemainUnitOnly(t *testing.T) {
	root := pbtest.BackendRoot(t)
	err := filepath.WalkDir(filepath.Join(root, "internal"), func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() || !strings.HasSuffix(path, "_test.go") {
			return nil
		}
		file, err := parser.ParseFile(token.NewFileSet(), path, nil, parser.ImportsOnly)
		if err != nil {
			return err
		}
		for _, imported := range file.Imports {
			dependency, err := strconv.Unquote(imported.Path.Value)
			if err != nil {
				return err
			}
			if strings.HasPrefix(dependency, "cordato/backend/tests/") ||
				dependency == "ganigeorgiev.com/pocketbase/pocketbase/tests" ||
				dependency == "ganigeorgiev.com/pocketbase/pocketbase/apis" ||
				dependency == "net/http/httptest" || dependency == "os/exec" {
				t.Errorf("%s usa integração/e2e fora de tests/: %s", path, dependency)
			}
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
}
