# Use the official .NET SDK image to build the app
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /app

# Copy the solution file and restore dependencies
COPY *.sln ./
COPY src/DashTab.Domain/*.csproj ./src/DashTab.Domain/
COPY src/DashTab.Application/*.csproj ./src/DashTab.Application/
COPY src/DashTab.Infrastructure/*.csproj ./src/DashTab.Infrastructure/
COPY src/DashTab.Api/*.csproj ./src/DashTab.Api/
RUN dotnet restore

# Copy the remaining source code
COPY . ./

# Build and publish the application
WORKDIR /app/src/DashTab.Api
RUN dotnet publish -c Release -o /out

# Use the official .NET ASP.NET runtime image for the final image
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app
COPY --from=build /out ./

# Expose port 80 (Render forwards traffic to the port the app listens on)
ENV ASPNETCORE_URLS=http://+:80
EXPOSE 80

# Start the application
ENTRYPOINT ["dotnet", "DashTab.Api.dll"]
