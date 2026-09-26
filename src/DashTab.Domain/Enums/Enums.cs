namespace DashTab.Domain.Enums;

public enum OrderStatus
{
    Open = 0,
    SentToKitchen = 1,
    PartiallyServed = 2,
    Served = 3,
    Closed = 4,
    Cancelled = 5,
    Paid = 6,
    Refunded = 7
}

public enum OrderType
{
    DineIn = 0,
    TakeAway = 1,
    Delivery = 2
}

public enum OrderItemStatus
{
    Pending = 0,
    SentToKitchen = 1,
    Preparing = 2,
    Ready = 3,
    Served = 4,
    Cancelled = 5
}

public enum PaymentStatus
{
    Pending = 0,
    Completed = 1,
    Failed = 2,
    Refunded = 3,
    PartiallyRefunded = 4
}

public enum KitchenTicketStatus
{
    Pending = 0,
    InProgress = 1,
    Ready = 2,
    Served = 3,
    Recalled = 4
}

public enum DiscountType
{
    Percentage = 0,
    FixedAmount = 1
}

public enum PaymentMethodType
{
    Cash = 0,
    Card = 1,
    Digital = 2,
    Other = 3
}
