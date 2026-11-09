package audio_test

import (
	"bytes"
	"errors"
	"testing"

	"cordato/backend/internal/application/audio"
)

func TestUseCase(t *testing.T) {
	for _, scenario := range []struct {
		name    string
		size    int
		failure error
	}{
		{"empty", 0, audio.ErrEmpty},
		{"one-byte", 1, nil},
		{"below-limit", audio.MaxBytes - 1, nil},
		{"exact-limit", audio.MaxBytes, nil},
		{"excess", audio.MaxBytes + 1, audio.ErrTooLarge},
	} {
		t.Run(scenario.name, func(t *testing.T) {
			content := bytes.Repeat([]byte{42}, scenario.size)
			original := bytes.Clone(content)
			useCase := audio.UseCase{}

			for range 2 {
				if err := useCase.Execute(audio.Input{Content: content}); !errors.Is(err, scenario.failure) {
					t.Fatalf("falha de aceite: %v", err)
				}
				if !bytes.Equal(content, original) {
					t.Fatal("aceite alterou conteúdo")
				}
			}
		})
	}
}
