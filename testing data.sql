BEGIN;

-------------------------------------------------------------------------------
-- 1. TENANTS
-------------------------------------------------------------------------------
INSERT INTO "Tenants" (
    "Id", "Name", "Slug", "Address", "Phone", "Email", 
    "CurrencyCode", "Locale", "Timezone", "LogoUrl", "IsActive", 
    "TenantId", "CreatedAt", "UpdatedAt", "CreatedBy", "UpdatedBy"
) VALUES (
    '11111111-1111-1111-1111-111111111111', 
    'Tasty Bistro', 
    'tasty-bistro', 
    '123 Main Street, Suite 400', 
    '+15550192834', 
    'admin@tastybistro.com', 
    'USD', 
    'en-US', 
    'America/New_York', 
    'https://example.com/logo.png', 
    true, 
    '11111111-1111-1111-1111-111111111111', 
    NOW(), NOW(), 'System', 'System'
);

-------------------------------------------------------------------------------
-- 2. PERMISSIONS & ROLES
-------------------------------------------------------------------------------
INSERT INTO "Permissions" ("Id", "Name", "Description", "Module") 
VALUES 
    ('a1111111-1111-1111-1111-111111111111', 'Orders.Read', 'View Orders', 'Orders'),
    ('a2222222-2222-2222-2222-222222222222', 'Orders.Create', 'Create New Orders', 'Orders'),
    ('a3333333-3333-3333-3333-333333333333', 'Products.Manage', 'Manage Products and Categories', 'Catalog');

INSERT INTO "Roles" (
    "Id", "Name", "Description", "IsSystem", "TenantId", "CreatedAt", "UpdatedAt", "CreatedBy", "UpdatedBy"
) VALUES (
    '22222222-2222-2222-2222-222222222222', 
    'Manager', 
    'Full access to restaurant operations', 
    true, 
    '11111111-1111-1111-1111-111111111111', 
    NOW(), NOW(), 'System', 'System'
);

INSERT INTO "PermissionRole" ("PermissionsId", "RolesId") 
VALUES 
    ('a1111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222'),
    ('a2222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222'),
    ('a3333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222');

-------------------------------------------------------------------------------
-- 3. USERS
-------------------------------------------------------------------------------
INSERT INTO "Users" (
    "Id", "Email", "Username", "PasswordHash", "FullName", "Pin", 
    "IsActive", "LastLoginAt", "TenantId", "CreatedAt", "UpdatedAt", "CreatedBy", "UpdatedBy"
) VALUES (
    '33333333-3333-3333-3333-333333333333', 
    'john.waiter@tastybistro.com', 
    'john_w', 
    'hashed_password_string_here', 
    'John Doe', 
    '1234', 
    true, 
    NOW(), 
    '11111111-1111-1111-1111-111111111111', 
    NOW(), NOW(), 'System', 'System'
);

INSERT INTO "RoleUser" ("RolesId", "UsersId") 
VALUES ('22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333');

-------------------------------------------------------------------------------
-- 4. TAX RATES & PAYMENT METHODS & DISCOUNTS
-------------------------------------------------------------------------------
INSERT INTO "TaxRates" (
    "Id", "Name", "Rate", "IsInclusive", "IsDefault", "IsActive", 
    "TenantId", "CreatedAt", "UpdatedAt", "CreatedBy", "UpdatedBy"
) VALUES (
    '44444444-4444-4444-4444-444444444444', 
    'Standard Sales Tax', 
    8.25, 
    false, 
    true, 
    true, 
    '11111111-1111-1111-1111-111111111111', 
    NOW(), NOW(), 'System', 'System'
);

INSERT INTO "PaymentMethods" (
    "Id", "Name", "Type", "IsActive", "SortOrder", 
    "TenantId", "CreatedAt", "UpdatedAt", "CreatedBy", "UpdatedBy"
) VALUES 
    ('b1111111-1111-1111-1111-111111111111', 'Cash', 1, true, 1, '11111111-1111-1111-1111-111111111111', NOW(), NOW(), 'System', 'System'),
    ('b2222222-2222-2222-2222-222222222222', 'Credit Card', 2, true, 2, '11111111-1111-1111-1111-111111111111', NOW(), NOW(), 'System', 'System');

INSERT INTO "Discounts" (
    "Id", "Name", "Type", "Value", "IsActive", "ValidFrom", "ValidUntil", 
    "TenantId", "CreatedAt", "UpdatedAt", "CreatedBy", "UpdatedBy"
) VALUES (
    'c1111111-1111-1111-1111-111111111111', 
    'Happy Hour 10%', 
    1, 
    10.00, 
    true, 
    NOW(), 
    NOW() + INTERVAL '30 days', 
    '11111111-1111-1111-1111-111111111111', 
    NOW(), NOW(), 'System', 'System'
);

-------------------------------------------------------------------------------
-- 5. CATEGORIES & PRODUCTS
-------------------------------------------------------------------------------
INSERT INTO "Categories" (
    "Id", "Name", "Description", "SortOrder", "Color", "Icon", "IsActive", 
    "ParentCategoryId", "TenantId", "CreatedAt", "UpdatedAt", "CreatedBy", "UpdatedBy"
) VALUES 
    ('55555555-5555-5555-5555-555555555551', 'Mains', 'Burgers, Mains, Entrees', 1, '#FF5733', 'hamburger', true, NULL, '11111111-1111-1111-1111-111111111111', NOW(), NOW(), 'System', 'System'),
    ('55555555-5555-5555-5555-555555555552', 'Drinks', 'Cold Beverages and Sodas', 2, '#337DEF', 'glass-martini', true, NULL, '11111111-1111-1111-1111-111111111111', NOW(), NOW(), 'System', 'System');

INSERT INTO "Products" (
    "Id", "CategoryId", "Name", "ShortName", "Description", "Price", "Cost", 
    "Sku", "Barcode", "ImageUrl", "SortOrder", "Color", "IsActive", "IsAvailable", 
    "TaxRateId", "KitchenPrinterId", "PrepTimeMinutes", "TenantId", "CreatedAt", "UpdatedAt", "CreatedBy", "UpdatedBy"
) VALUES 
    (
        '66666666-6666-6666-6666-666666666661', 
        '55555555-5555-5555-5555-555555555551', 
        'Classic Cheeseburger', 'Burger', 'Beef patty with cheddar cheese & lettuce', 14.50, 4.20, 
        'BURGER-01', '123456789012', 'https://example.com/burger.jpg', 1, '#FF5733', true, true, 
        '44444444-4444-4444-4444-444444444444', NULL, 12, '11111111-1111-1111-1111-111111111111', NOW(), NOW(), 'System', 'System'
    ),
    (
        '66666666-6666-6666-6666-666666666662', 
        '55555555-5555-5555-5555-555555555552', 
        'Iced Lemon Tea', 'Iced Tea', 'Freshly brewed lemon tea', 3.99, 0.45, 
        'DRINK-01', '123456789013', 'https://example.com/tea.jpg', 1, '#337DEF', true, true, 
        '44444444-4444-4444-4444-444444444444', NULL, 3, '11111111-1111-1111-1111-111111111111', NOW(), NOW(), 'System', 'System'
    );

-------------------------------------------------------------------------------
-- 6. MODIFIERS & MODIFIER GROUPS
-------------------------------------------------------------------------------
INSERT INTO "ModifierGroups" (
    "Id", "Name", "MinSelections", "MaxSelections", "IsRequired", "SortOrder", 
    "TenantId", "CreatedAt", "UpdatedAt", "CreatedBy", "UpdatedBy"
) VALUES (
    '77777777-7777-7777-7777-777777777777', 
    'Burger Add-ons', 0, 3, false, 1, 
    '11111111-1111-1111-1111-111111111111', NOW(), NOW(), 'System', 'System'
);

INSERT INTO "Modifiers" (
    "Id", "ModifierGroupId", "Name", "PriceAdjustment", "IsActive", "SortOrder", 
    "TenantId", "CreatedAt", "UpdatedAt", "CreatedBy", "UpdatedBy"
) VALUES (
    '88888888-8888-8888-8888-888888888888', 
    '77777777-7777-7777-7777-777777777777', 
    'Extra Bacon', 2.00, true, 1, 
    '11111111-1111-1111-1111-111111111111', NOW(), NOW(), 'System', 'System'
);

INSERT INTO "ModifierGroupProduct" ("ModifierGroupsId", "ProductsId") 
VALUES ('77777777-7777-7777-7777-777777777777', '66666666-6666-6666-6666-666666666661');

-------------------------------------------------------------------------------
-- 7. FLOORS & TABLES
-------------------------------------------------------------------------------
INSERT INTO "Floors" (
    "Id", "Name", "BackgroundColor", "BackgroundImageUrl", "IsActive", 
    "TenantId", "CreatedAt", "UpdatedAt", "CreatedBy", "UpdatedBy"
) VALUES (
    '99999999-9999-9999-9999-999999999999', 
    'Main Dining Room', '#FFFFFF', NULL, true, 
    '11111111-1111-1111-1111-111111111111', NOW(), NOW(), 'System', 'System'
);

INSERT INTO "Tables" (
    "Id", "FloorId", "Name", "Capacity", "Status", "X", "Y", "Width", "Height", "Shape", 
    "TenantId", "CreatedAt", "UpdatedAt", "CreatedBy", "UpdatedBy"
) VALUES (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 
    '99999999-9999-9999-9999-999999999999', 
    'T-01', 4, 2, 120.0, 200.0, 100.0, 100.0, 1, 
    '11111111-1111-1111-1111-111111111111', NOW(), NOW(), 'System', 'System'
);

-------------------------------------------------------------------------------
-- 8. ORDERS & ORDER ITEMS
-------------------------------------------------------------------------------
INSERT INTO "Orders" (
    "Id", "OrderNumber", "OrderType", "Status", "TableId", "CustomerId", "WaiterId", 
    "Subtotal", "TaxAmount", "DiscountAmount", "Total", "Notes", "ClosedAt", 
    "TenantId", "CreatedAt", "UpdatedAt", "CreatedBy", "UpdatedBy"
) VALUES (
    'dddddddd-dddd-dddd-dddd-dddddddddddd', 
    'ORD-2026-001', 1, 1, 
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NULL, 
    '33333333-3333-3333-3333-333333333333', 
    20.49, 1.69, 0.00, 22.18, 
    'Customer requested extra napkins', NULL, 
    '11111111-1111-1111-1111-111111111111', NOW(), NOW(), 'System', 'System'
);

INSERT INTO "OrderItems" (
    "Id", "OrderId", "ProductId", "ProductName", "Quantity", "UnitPrice", 
    "DiscountAmount", "TaxRate", "TaxAmount", "Subtotal", "Total", "Notes", 
    "Status", "SentToKitchenAt", "TenantId", "CreatedAt", "UpdatedAt", "CreatedBy", "UpdatedBy"
) VALUES 
    (
        'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1', 
        'dddddddd-dddd-dddd-dddd-dddddddddddd', 
        '66666666-6666-6666-6666-666666666661', 
        'Classic Cheeseburger', 1, 14.50, 0.00, 8.25, 1.36, 16.50, 17.86, 
        'Medium Rare', 1, NOW(), '11111111-1111-1111-1111-111111111111', NOW(), NOW(), 'System', 'System'
    ),
    (
        'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee2', 
        'dddddddd-dddd-dddd-dddd-dddddddddddd', 
        '66666666-6666-6666-6666-666666666662', 
        'Iced Lemon Tea', 1, 3.99, 0.00, 8.25, 0.33, 3.99, 4.32, 
        'Less ice', 1, NOW(), '11111111-1111-1111-1111-111111111111', NOW(), NOW(), 'System', 'System'
    );

INSERT INTO "OrderItemModifiers" (
    "Id", "OrderItemId", "ModifierId", "ModifierName", "PriceAdjustment", 
    "TenantId", "CreatedAt", "UpdatedAt", "CreatedBy", "UpdatedBy"
) VALUES (
    'f1111111-1111-1111-1111-111111111111', 
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1', 
    '88888888-8888-8888-8888-888888888888', 
    'Extra Bacon', 2.00, 
    '11111111-1111-1111-1111-111111111111', NOW(), NOW(), 'System', 'System'
);

-------------------------------------------------------------------------------
-- 9. KITCHEN TICKETS, PAYMENTS & AUDIT LOGS
-------------------------------------------------------------------------------
INSERT INTO "KitchenTickets" (
    "Id", "OrderId", "TicketNumber", "Status", "PrinterId", "StartedAt", "CompletedAt", 
    "TenantId", "CreatedAt", "UpdatedAt", "CreatedBy", "UpdatedBy"
) VALUES (
    'f2222222-2222-2222-2222-222222222222', 
    'dddddddd-dddd-dddd-dddd-dddddddddddd', 
    'KT-001', 1, NULL, NOW(), NULL, 
    '11111111-1111-1111-1111-111111111111', NOW(), NOW(), 'System', 'System'
);

INSERT INTO "Payments" (
    "Id", "OrderId", "PaymentMethodId", "Amount", "TipAmount", "ChangeAmount", 
    "Status", "Reference", "TenantId", "CreatedAt", "UpdatedAt", "CreatedBy", "UpdatedBy"
) VALUES (
    'f3333333-3333-3333-3333-333333333333', 
    'dddddddd-dddd-dddd-dddd-dddddddddddd', 
    'b2222222-2222-2222-2222-222222222222', 
    22.18, 3.00, 0.00, 1, 'TXN_987654321', 
    '11111111-1111-1111-1111-111111111111', NOW(), NOW(), 'System', 'System'
);

INSERT INTO "AuditLogs" (
    "Id", "UserId", "Action", "EntityType", "EntityId", "OldValues", "NewValues", 
    "IpAddress", "TenantId", "CreatedAt", "UpdatedAt", "CreatedBy", "UpdatedBy"
) VALUES (
    'f4444444-4444-4444-4444-444444444444', 
    '33333333-3333-3333-3333-333333333333', 
    'CREATE', 'Order', 'dddddddd-dddd-dddd-dddd-dddddddddddd', NULL, '{"Status": 1, "Total": 22.18}', 
    '127.0.0.1', '11111111-1111-1111-1111-111111111111', NOW(), NOW(), 'System', 'System'
);

COMMIT;