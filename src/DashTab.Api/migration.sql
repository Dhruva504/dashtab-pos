CREATE TABLE IF NOT EXISTS "__EFMigrationsHistory" (
    "MigrationId" character varying(150) NOT NULL,
    "ProductVersion" character varying(32) NOT NULL,
    CONSTRAINT "PK___EFMigrationsHistory" PRIMARY KEY ("MigrationId")
);

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE TABLE "Permissions" (
        "Id" uuid NOT NULL,
        "Name" text NOT NULL,
        "Description" text,
        "Module" text NOT NULL,
        CONSTRAINT "PK_Permissions" PRIMARY KEY ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE TABLE "Tenants" (
        "Id" uuid NOT NULL,
        "Name" text NOT NULL,
        "Slug" text NOT NULL,
        "Address" text,
        "Phone" text,
        "Email" text,
        "CurrencyCode" text NOT NULL,
        "Locale" text NOT NULL,
        "Timezone" text NOT NULL,
        "LogoUrl" text,
        "IsActive" boolean NOT NULL,
        "TenantId" uuid NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        "UpdatedAt" timestamp with time zone NOT NULL,
        "CreatedBy" text,
        "UpdatedBy" text,
        CONSTRAINT "PK_Tenants" PRIMARY KEY ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE TABLE "Categories" (
        "Id" uuid NOT NULL,
        "Name" text NOT NULL,
        "Description" text,
        "SortOrder" integer NOT NULL,
        "Color" text,
        "Icon" text,
        "IsActive" boolean NOT NULL,
        "ParentCategoryId" uuid,
        "TenantId" uuid NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        "UpdatedAt" timestamp with time zone NOT NULL,
        "CreatedBy" text,
        "UpdatedBy" text,
        "DeletedAt" timestamp with time zone,
        "DeletedBy" text,
        CONSTRAINT "PK_Categories" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_Categories_Categories_ParentCategoryId" FOREIGN KEY ("ParentCategoryId") REFERENCES "Categories" ("Id"),
        CONSTRAINT "FK_Categories_Tenants_TenantId" FOREIGN KEY ("TenantId") REFERENCES "Tenants" ("Id") ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE TABLE "Discounts" (
        "Id" uuid NOT NULL,
        "Name" text NOT NULL,
        "Type" integer NOT NULL,
        "Value" numeric NOT NULL,
        "IsActive" boolean NOT NULL,
        "ValidFrom" timestamp with time zone,
        "ValidUntil" timestamp with time zone,
        "TenantId" uuid NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        "UpdatedAt" timestamp with time zone NOT NULL,
        "CreatedBy" text,
        "UpdatedBy" text,
        CONSTRAINT "PK_Discounts" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_Discounts_Tenants_TenantId" FOREIGN KEY ("TenantId") REFERENCES "Tenants" ("Id") ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE TABLE "ModifierGroups" (
        "Id" uuid NOT NULL,
        "Name" text NOT NULL,
        "MinSelections" integer NOT NULL,
        "MaxSelections" integer NOT NULL,
        "IsRequired" boolean NOT NULL,
        "SortOrder" integer NOT NULL,
        "TenantId" uuid NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        "UpdatedAt" timestamp with time zone NOT NULL,
        "CreatedBy" text,
        "UpdatedBy" text,
        CONSTRAINT "PK_ModifierGroups" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_ModifierGroups_Tenants_TenantId" FOREIGN KEY ("TenantId") REFERENCES "Tenants" ("Id") ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE TABLE "PaymentMethods" (
        "Id" uuid NOT NULL,
        "Name" text NOT NULL,
        "Type" integer NOT NULL,
        "IsActive" boolean NOT NULL,
        "SortOrder" integer NOT NULL,
        "TenantId" uuid NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        "UpdatedAt" timestamp with time zone NOT NULL,
        "CreatedBy" text,
        "UpdatedBy" text,
        CONSTRAINT "PK_PaymentMethods" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_PaymentMethods_Tenants_TenantId" FOREIGN KEY ("TenantId") REFERENCES "Tenants" ("Id") ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE TABLE "Roles" (
        "Id" uuid NOT NULL,
        "Name" text NOT NULL,
        "Description" text,
        "IsSystem" boolean NOT NULL,
        "TenantId" uuid NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        "UpdatedAt" timestamp with time zone NOT NULL,
        "CreatedBy" text,
        "UpdatedBy" text,
        CONSTRAINT "PK_Roles" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_Roles_Tenants_TenantId" FOREIGN KEY ("TenantId") REFERENCES "Tenants" ("Id") ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE TABLE "TaxRates" (
        "Id" uuid NOT NULL,
        "Name" text NOT NULL,
        "Rate" numeric NOT NULL,
        "IsInclusive" boolean NOT NULL,
        "IsDefault" boolean NOT NULL,
        "IsActive" boolean NOT NULL,
        "TenantId" uuid NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        "UpdatedAt" timestamp with time zone NOT NULL,
        "CreatedBy" text,
        "UpdatedBy" text,
        CONSTRAINT "PK_TaxRates" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_TaxRates_Tenants_TenantId" FOREIGN KEY ("TenantId") REFERENCES "Tenants" ("Id") ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE TABLE "Users" (
        "Id" uuid NOT NULL,
        "Email" text,
        "Username" text NOT NULL,
        "PasswordHash" text NOT NULL,
        "FullName" text,
        "Pin" text,
        "IsActive" boolean NOT NULL,
        "LastLoginAt" timestamp with time zone,
        "TenantId" uuid NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        "UpdatedAt" timestamp with time zone NOT NULL,
        "CreatedBy" text,
        "UpdatedBy" text,
        "DeletedAt" timestamp with time zone,
        "DeletedBy" text,
        CONSTRAINT "PK_Users" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_Users_Tenants_TenantId" FOREIGN KEY ("TenantId") REFERENCES "Tenants" ("Id") ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE TABLE "Modifiers" (
        "Id" uuid NOT NULL,
        "ModifierGroupId" uuid NOT NULL,
        "Name" text NOT NULL,
        "PriceAdjustment" numeric NOT NULL,
        "IsActive" boolean NOT NULL,
        "SortOrder" integer NOT NULL,
        "TenantId" uuid NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        "UpdatedAt" timestamp with time zone NOT NULL,
        "CreatedBy" text,
        "UpdatedBy" text,
        CONSTRAINT "PK_Modifiers" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_Modifiers_ModifierGroups_ModifierGroupId" FOREIGN KEY ("ModifierGroupId") REFERENCES "ModifierGroups" ("Id") ON DELETE CASCADE,
        CONSTRAINT "FK_Modifiers_Tenants_TenantId" FOREIGN KEY ("TenantId") REFERENCES "Tenants" ("Id") ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE TABLE "PermissionRole" (
        "PermissionsId" uuid NOT NULL,
        "RolesId" uuid NOT NULL,
        CONSTRAINT "PK_PermissionRole" PRIMARY KEY ("PermissionsId", "RolesId"),
        CONSTRAINT "FK_PermissionRole_Permissions_PermissionsId" FOREIGN KEY ("PermissionsId") REFERENCES "Permissions" ("Id") ON DELETE CASCADE,
        CONSTRAINT "FK_PermissionRole_Roles_RolesId" FOREIGN KEY ("RolesId") REFERENCES "Roles" ("Id") ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE TABLE "Products" (
        "Id" uuid NOT NULL,
        "CategoryId" uuid NOT NULL,
        "Name" text NOT NULL,
        "ShortName" text,
        "Description" text,
        "Price" numeric NOT NULL,
        "Cost" numeric,
        "Sku" text,
        "Barcode" text,
        "ImageUrl" text,
        "SortOrder" integer NOT NULL,
        "Color" text,
        "IsActive" boolean NOT NULL,
        "IsAvailable" boolean NOT NULL,
        "TaxRateId" uuid,
        "KitchenPrinterId" uuid,
        "PrepTimeMinutes" integer,
        "TenantId" uuid NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        "UpdatedAt" timestamp with time zone NOT NULL,
        "CreatedBy" text,
        "UpdatedBy" text,
        "DeletedAt" timestamp with time zone,
        "DeletedBy" text,
        CONSTRAINT "PK_Products" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_Products_Categories_CategoryId" FOREIGN KEY ("CategoryId") REFERENCES "Categories" ("Id") ON DELETE CASCADE,
        CONSTRAINT "FK_Products_TaxRates_TaxRateId" FOREIGN KEY ("TaxRateId") REFERENCES "TaxRates" ("Id"),
        CONSTRAINT "FK_Products_Tenants_TenantId" FOREIGN KEY ("TenantId") REFERENCES "Tenants" ("Id") ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE TABLE "AuditLogs" (
        "Id" uuid NOT NULL,
        "UserId" uuid,
        "Action" text NOT NULL,
        "EntityType" text NOT NULL,
        "EntityId" text NOT NULL,
        "OldValues" text,
        "NewValues" text,
        "IpAddress" text,
        "TenantId" uuid NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        "UpdatedAt" timestamp with time zone NOT NULL,
        "CreatedBy" text,
        "UpdatedBy" text,
        CONSTRAINT "PK_AuditLogs" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_AuditLogs_Tenants_TenantId" FOREIGN KEY ("TenantId") REFERENCES "Tenants" ("Id") ON DELETE CASCADE,
        CONSTRAINT "FK_AuditLogs_Users_UserId" FOREIGN KEY ("UserId") REFERENCES "Users" ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE TABLE "Orders" (
        "Id" uuid NOT NULL,
        "OrderNumber" text NOT NULL,
        "OrderType" integer NOT NULL,
        "Status" integer NOT NULL,
        "TableId" uuid,
        "CustomerId" uuid,
        "WaiterId" uuid,
        "Subtotal" numeric NOT NULL,
        "TaxAmount" numeric NOT NULL,
        "DiscountAmount" numeric NOT NULL,
        "Total" numeric NOT NULL,
        "Notes" text,
        "ClosedAt" timestamp with time zone,
        "TenantId" uuid NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        "UpdatedAt" timestamp with time zone NOT NULL,
        "CreatedBy" text,
        "UpdatedBy" text,
        CONSTRAINT "PK_Orders" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_Orders_Tenants_TenantId" FOREIGN KEY ("TenantId") REFERENCES "Tenants" ("Id") ON DELETE CASCADE,
        CONSTRAINT "FK_Orders_Users_WaiterId" FOREIGN KEY ("WaiterId") REFERENCES "Users" ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE TABLE "RoleUser" (
        "RolesId" uuid NOT NULL,
        "UsersId" uuid NOT NULL,
        CONSTRAINT "PK_RoleUser" PRIMARY KEY ("RolesId", "UsersId"),
        CONSTRAINT "FK_RoleUser_Roles_RolesId" FOREIGN KEY ("RolesId") REFERENCES "Roles" ("Id") ON DELETE CASCADE,
        CONSTRAINT "FK_RoleUser_Users_UsersId" FOREIGN KEY ("UsersId") REFERENCES "Users" ("Id") ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE TABLE "ModifierGroupProduct" (
        "ModifierGroupsId" uuid NOT NULL,
        "ProductsId" uuid NOT NULL,
        CONSTRAINT "PK_ModifierGroupProduct" PRIMARY KEY ("ModifierGroupsId", "ProductsId"),
        CONSTRAINT "FK_ModifierGroupProduct_ModifierGroups_ModifierGroupsId" FOREIGN KEY ("ModifierGroupsId") REFERENCES "ModifierGroups" ("Id") ON DELETE CASCADE,
        CONSTRAINT "FK_ModifierGroupProduct_Products_ProductsId" FOREIGN KEY ("ProductsId") REFERENCES "Products" ("Id") ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE TABLE "KitchenTickets" (
        "Id" uuid NOT NULL,
        "OrderId" uuid NOT NULL,
        "TicketNumber" text NOT NULL,
        "Status" integer NOT NULL,
        "PrinterId" uuid,
        "StartedAt" timestamp with time zone,
        "CompletedAt" timestamp with time zone,
        "TenantId" uuid NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        "UpdatedAt" timestamp with time zone NOT NULL,
        "CreatedBy" text,
        "UpdatedBy" text,
        CONSTRAINT "PK_KitchenTickets" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_KitchenTickets_Orders_OrderId" FOREIGN KEY ("OrderId") REFERENCES "Orders" ("Id") ON DELETE CASCADE,
        CONSTRAINT "FK_KitchenTickets_Tenants_TenantId" FOREIGN KEY ("TenantId") REFERENCES "Tenants" ("Id") ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE TABLE "OrderItems" (
        "Id" uuid NOT NULL,
        "OrderId" uuid NOT NULL,
        "ProductId" uuid NOT NULL,
        "ProductName" text NOT NULL,
        "Quantity" integer NOT NULL,
        "UnitPrice" numeric NOT NULL,
        "DiscountAmount" numeric NOT NULL,
        "TaxRate" numeric NOT NULL,
        "TaxAmount" numeric NOT NULL,
        "Subtotal" numeric NOT NULL,
        "Total" numeric NOT NULL,
        "Notes" text,
        "Status" integer NOT NULL,
        "SentToKitchenAt" timestamp with time zone,
        "TenantId" uuid NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        "UpdatedAt" timestamp with time zone NOT NULL,
        "CreatedBy" text,
        "UpdatedBy" text,
        CONSTRAINT "PK_OrderItems" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_OrderItems_Orders_OrderId" FOREIGN KEY ("OrderId") REFERENCES "Orders" ("Id") ON DELETE CASCADE,
        CONSTRAINT "FK_OrderItems_Products_ProductId" FOREIGN KEY ("ProductId") REFERENCES "Products" ("Id") ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE TABLE "Payments" (
        "Id" uuid NOT NULL,
        "OrderId" uuid NOT NULL,
        "PaymentMethodId" uuid NOT NULL,
        "Amount" numeric NOT NULL,
        "TipAmount" numeric NOT NULL,
        "ChangeAmount" numeric NOT NULL,
        "Status" integer NOT NULL,
        "Reference" text,
        "TenantId" uuid NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        "UpdatedAt" timestamp with time zone NOT NULL,
        "CreatedBy" text,
        "UpdatedBy" text,
        CONSTRAINT "PK_Payments" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_Payments_Orders_OrderId" FOREIGN KEY ("OrderId") REFERENCES "Orders" ("Id") ON DELETE CASCADE,
        CONSTRAINT "FK_Payments_PaymentMethods_PaymentMethodId" FOREIGN KEY ("PaymentMethodId") REFERENCES "PaymentMethods" ("Id") ON DELETE CASCADE,
        CONSTRAINT "FK_Payments_Tenants_TenantId" FOREIGN KEY ("TenantId") REFERENCES "Tenants" ("Id") ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE TABLE "OrderItemModifiers" (
        "Id" uuid NOT NULL,
        "OrderItemId" uuid NOT NULL,
        "ModifierId" uuid NOT NULL,
        "ModifierName" text NOT NULL,
        "PriceAdjustment" numeric NOT NULL,
        "TenantId" uuid NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        "UpdatedAt" timestamp with time zone NOT NULL,
        "CreatedBy" text,
        "UpdatedBy" text,
        CONSTRAINT "PK_OrderItemModifiers" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_OrderItemModifiers_Modifiers_ModifierId" FOREIGN KEY ("ModifierId") REFERENCES "Modifiers" ("Id") ON DELETE CASCADE,
        CONSTRAINT "FK_OrderItemModifiers_OrderItems_OrderItemId" FOREIGN KEY ("OrderItemId") REFERENCES "OrderItems" ("Id") ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_AuditLogs_TenantId" ON "AuditLogs" ("TenantId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_AuditLogs_UserId" ON "AuditLogs" ("UserId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_Categories_ParentCategoryId" ON "Categories" ("ParentCategoryId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_Categories_TenantId" ON "Categories" ("TenantId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_Discounts_TenantId" ON "Discounts" ("TenantId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_KitchenTickets_OrderId" ON "KitchenTickets" ("OrderId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_KitchenTickets_TenantId" ON "KitchenTickets" ("TenantId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_ModifierGroupProduct_ProductsId" ON "ModifierGroupProduct" ("ProductsId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_ModifierGroups_TenantId" ON "ModifierGroups" ("TenantId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_Modifiers_ModifierGroupId" ON "Modifiers" ("ModifierGroupId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_Modifiers_TenantId" ON "Modifiers" ("TenantId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_OrderItemModifiers_ModifierId" ON "OrderItemModifiers" ("ModifierId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_OrderItemModifiers_OrderItemId" ON "OrderItemModifiers" ("OrderItemId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_OrderItems_OrderId" ON "OrderItems" ("OrderId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_OrderItems_ProductId" ON "OrderItems" ("ProductId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_Orders_TenantId" ON "Orders" ("TenantId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_Orders_WaiterId" ON "Orders" ("WaiterId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_PaymentMethods_TenantId" ON "PaymentMethods" ("TenantId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_Payments_OrderId" ON "Payments" ("OrderId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_Payments_PaymentMethodId" ON "Payments" ("PaymentMethodId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_Payments_TenantId" ON "Payments" ("TenantId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_PermissionRole_RolesId" ON "PermissionRole" ("RolesId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_Products_CategoryId" ON "Products" ("CategoryId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_Products_TaxRateId" ON "Products" ("TaxRateId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_Products_TenantId" ON "Products" ("TenantId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_Roles_TenantId" ON "Roles" ("TenantId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_RoleUser_UsersId" ON "RoleUser" ("UsersId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_TaxRates_TenantId" ON "TaxRates" ("TenantId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    CREATE INDEX "IX_Users_TenantId" ON "Users" ("TenantId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260719184928_InitialCreate') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260719184928_InitialCreate', '9.0.0');
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260723175941_Phase2_FloorPlan') THEN
    CREATE TABLE "Floors" (
        "Id" uuid NOT NULL,
        "Name" text NOT NULL,
        "BackgroundColor" text NOT NULL,
        "BackgroundImageUrl" text,
        "IsActive" boolean NOT NULL,
        "TenantId" uuid NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        "UpdatedAt" timestamp with time zone NOT NULL,
        "CreatedBy" text,
        "UpdatedBy" text,
        CONSTRAINT "PK_Floors" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_Floors_Tenants_TenantId" FOREIGN KEY ("TenantId") REFERENCES "Tenants" ("Id") ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260723175941_Phase2_FloorPlan') THEN
    CREATE TABLE "Tables" (
        "Id" uuid NOT NULL,
        "FloorId" uuid NOT NULL,
        "Name" text NOT NULL,
        "Capacity" integer NOT NULL,
        "Status" integer NOT NULL,
        "X" double precision NOT NULL,
        "Y" double precision NOT NULL,
        "Width" double precision NOT NULL,
        "Height" double precision NOT NULL,
        "Shape" integer NOT NULL,
        "TenantId" uuid NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        "UpdatedAt" timestamp with time zone NOT NULL,
        "CreatedBy" text,
        "UpdatedBy" text,
        CONSTRAINT "PK_Tables" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_Tables_Floors_FloorId" FOREIGN KEY ("FloorId") REFERENCES "Floors" ("Id") ON DELETE CASCADE,
        CONSTRAINT "FK_Tables_Tenants_TenantId" FOREIGN KEY ("TenantId") REFERENCES "Tenants" ("Id") ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260723175941_Phase2_FloorPlan') THEN
    CREATE INDEX "IX_Orders_TableId" ON "Orders" ("TableId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260723175941_Phase2_FloorPlan') THEN
    CREATE INDEX "IX_Floors_TenantId" ON "Floors" ("TenantId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260723175941_Phase2_FloorPlan') THEN
    CREATE INDEX "IX_Tables_FloorId" ON "Tables" ("FloorId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260723175941_Phase2_FloorPlan') THEN
    CREATE INDEX "IX_Tables_TenantId" ON "Tables" ("TenantId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260723175941_Phase2_FloorPlan') THEN
    ALTER TABLE "Orders" ADD CONSTRAINT "FK_Orders_Tables_TableId" FOREIGN KEY ("TableId") REFERENCES "Tables" ("Id");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260723175941_Phase2_FloorPlan') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260723175941_Phase2_FloorPlan', '9.0.0');
    END IF;
END $EF$;
COMMIT;

