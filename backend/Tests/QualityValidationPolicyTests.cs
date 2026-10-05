using System.Text.Json;
using ManufacturingCoordinator.Api.Helpers;
using Xunit;

public class QualityValidationPolicyTests
{
    private static Dictionary<string, object?> Checks() => new() {
        ["supplierValidation"] = "PASSED", ["budgetCheck"] = "PASSED",
        ["poMathematicalCheck"] = "PASSED", ["materialValidation"] = "PASSED"
    };
    [Fact]
    public void MissingCheckCannotBeCleared()
    {
        var results = Checks(); results.Remove("materialValidation");
        Assert.False(QualityValidationPolicy.NonQualityChecksPassed(results));
    }
    [Theory]
    [InlineData("moqCheck")]
    [InlineData("availabilityCheck")]
    [InlineData("bestChoiceCheck")]
    public void QaClearanceCannotOverrideFailedProposalCheck(string key)
    {
        var results = Checks(); results[key] = "FAILED"; results["manualResolutionStatus"] = "RESOLVED";
        Assert.False(QualityValidationPolicy.NonQualityChecksPassed(results));
    }
    [Fact]
    public void VersionTwoRequiresCompleteEvidence()
    {
        var results = Checks(); results["assessmentVersion"] = 2;
        Assert.False(QualityValidationPolicy.NonQualityChecksPassed(results));
        foreach (var key in new[] { "quantityCheck", "moqCheck", "packSizeCheck", "supplierVerification", "availabilityCheck", "bestChoiceCheck" }) results[key] = "PASS";
        Assert.True(QualityValidationPolicy.NonQualityChecksPassed(results));
    }
}
