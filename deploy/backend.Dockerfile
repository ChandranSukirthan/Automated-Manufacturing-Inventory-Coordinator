FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY backend/ManufacturingCoordinator.Api.csproj backend/
RUN dotnet restore backend/ManufacturingCoordinator.Api.csproj
COPY backend/ backend/
RUN dotnet publish backend/ManufacturingCoordinator.Api.csproj -c Release -o /out --no-restore -p:UseAppHost=false
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build --chown=app:app /out/ ./
ENV ASPNETCORE_URLS=http://+:8080
USER app
EXPOSE 8080
ENTRYPOINT ["dotnet", "ManufacturingCoordinator.Api.dll"]
