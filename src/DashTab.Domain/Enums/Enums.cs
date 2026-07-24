namespace DashTab.Domain.Enums;

public enum OrderStatus
{
    Draft = 0,
    Open = 1,
    Paid = 2,
    PartiallyPaid = 3,
    Voided = 4,
    Refunded = 5,
    Closed = 6
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
