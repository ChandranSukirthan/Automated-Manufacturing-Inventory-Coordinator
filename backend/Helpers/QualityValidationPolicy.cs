using System.Text.Json;
namespace ManufacturingCoordinator.Api.Helpers;

public static class QualityValidationPolicy
{
    private static readonly string[] CoreChecks = { "supplierValidation", "budgetCheck", "poMathematicalCheck", "materialValidation" };
    private static readonly string[] ProposalChecks = { "quantityCheck", "moqCheck", "packSizeCheck", "supplierVerification", "availabilityCheck", "bestChoiceCheck" };
    public static bool NonQualityChecksPassed(JsonElement results)
    {
        bool Passed(string key) => results.TryGetProperty(key, out var value) && value.ValueKind == JsonValueKind.String &&
            (value.GetString() == "PASS" || value.GetString() == "PASSED");
        if (!CoreChecks.All(Passed)) return false;
        bool complete = results.TryGetProperty("assessmentVersion", out var version) && version.TryGetInt32(out var number) && number >= 2;
        return ProposalChecks.All(key => (!complete && !results.TryGetProperty(key, out _)) || Passed(key));
    }
    public static bool NonQualityChecksPassed(Dictionary<string, object?> results)
    {
        using var document = JsonDocument.Parse(JsonSerializer.Serialize(results));
        return NonQualityChecksPassed(document.RootElement);
    }
}
