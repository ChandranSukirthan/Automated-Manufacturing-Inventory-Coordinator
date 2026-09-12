using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using ManufacturingCoordinator.Api.DTOs.Administration;

namespace ManufacturingCoordinator.Api.Interfaces
{
    public interface IAdminService
    {
        // User Management
        Task<List<UserListDto>> GetAllUsersAsync();
        Task<UserListDto> GetUserByIdAsync(Guid id);
        Task<UserListDto> CreateUserAsync(AdminCreateUserDto dto);
        Task<UserListDto> UpdateUserAsync(Guid id, AdminUpdateUserDto dto);
        Task ActivateUserAsync(Guid id);
        Task DeactivateUserAsync(Guid id);
        Task<UserListDto> AssignRoleAsync(Guid id, AssignRoleDto dto);

        // Roles
        Task<List<string>> GetAllRolesAsync();

        // Agent Workflows
        Task<List<AgentWorkflowDto>> GetAllWorkflowsAsync();
        Task<AgentWorkflowDto> GetWorkflowByIdAsync(Guid id);

        // System Health
        Task<SystemHealthDto> GetSystemHealthAsync();
    }
}
