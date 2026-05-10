package errors

import "fmt"

// Domain error types yang dipakai semua service
type ErrorCode string

const (
	ErrNotFound     ErrorCode = "NOT_FOUND"
	ErrValidation   ErrorCode = "VALIDATION_ERROR"
	ErrUnauthorized ErrorCode = "UNAUTHORIZED"
	ErrForbidden    ErrorCode = "FORBIDDEN"
	ErrConflict     ErrorCode = "CONFLICT"
	ErrInternal     ErrorCode = "INTERNAL_ERROR"
)

type DomainError struct {
	Code    ErrorCode
	Message string
	Err     error // Underlying error (for logging, not exposed to client)
}

func (e *DomainError) Error() string {
	if e.Err != nil {
		return fmt.Sprintf("%s: %s: %v", e.Code, e.Message, e.Err)
	}
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

func NewNotFound(resource string) *DomainError {
	return &DomainError{Code: ErrNotFound, Message: resource + " not found"}
}
func NewValidation(msg string) *DomainError {
	return &DomainError{Code: ErrValidation, Message: msg}
}
func NewConflict(msg string) *DomainError {
	return &DomainError{Code: ErrConflict, Message: msg}
}
func NewUnauthorized() *DomainError {
	return &DomainError{Code: ErrUnauthorized, Message: "authentication required"}
}
func NewInternal(err error) *DomainError {
	return &DomainError{Code: ErrInternal, Message: "internal server error", Err: err}
}
