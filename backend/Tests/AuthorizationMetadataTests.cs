using System.Linq;
using backend.Controllers;
using ManufacturingCoordinator.Api.Controllers;
using Microsoft.AspNetCore.Authorization;
using Xunit;

namespace backend.Tests;

public class AuthorizationMetadataTests
{
    [Theory]
    [InlineData(typeof(InventoryController))]
    [InlineData(typeof(ShiftsController))]
    public void FloorWorkerOperationalControllers_DeclareTheExpectedRoles(System.Type controllerType)
    {
        var authorization = controllerType
            .GetCustomAttributes(typeof(AuthorizeAttribute), inherit: true)
            .Cast<AuthorizeAttribute>()
            .Single();

        Assert.Equal(controllerType == typeof(InventoryController)
            ? "FloorWorker,QualityInspector,SupplyChainManager,ITAdmin"
            : "FloorWorker,SupplyChainManager,ITAdmin", authorization.Roles);
    }
}
