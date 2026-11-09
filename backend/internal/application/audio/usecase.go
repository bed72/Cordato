package audio

const MaxBytes = 2_097_152

const (
	ErrEmpty    rejection = "Conteúdo de áudio vazio."
	ErrTooLarge rejection = "Conteúdo de áudio acima do limite."
)

type rejection string

func (e rejection) Error() string { return string(e) }

type Input struct {
	Content []byte
}

type UseCase struct{}

func (UseCase) Execute(input Input) error {
	if len(input.Content) == 0 {
		return ErrEmpty
	}
	if len(input.Content) > MaxBytes {
		return ErrTooLarge
	}

	return nil
}
