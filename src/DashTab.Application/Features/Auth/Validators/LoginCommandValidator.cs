using FluentValidation;

namespace DashTab.Application.Features.Auth.Validators;

public class LoginCommandValidator : AbstractValidator<Commands.LoginCommand>
{
    public LoginCommandValidator()
    {
        RuleFor(v => v.Username).NotEmpty().WithMessage("Username is required.");
        RuleFor(v => v.Password).NotEmpty().WithMessage("Password is required.");
        RuleFor(v => v.TenantSlug).NotEmpty().WithMessage("Tenant identifier is required.");
    }
}
