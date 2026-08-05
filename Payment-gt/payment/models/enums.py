# models/enums.py
from enum import Enum


class PaymentStatus(str, Enum):
    PENDING = "pending"
    AUTHORIZED = "authorized"
    CAPTURED = "captured"
    PARTIALLY_CAPTURED = "partially_captured"
    VOIDED = "voided"
    FAILED = "failed"
    REFUNDED = "refunded"
    PARTIALLY_REFUNDED = "partially_refunded"
    EXPIRED = "expired"

class TransactionType(str, Enum):
    AUTHORIZATION = "authorization"
    CAPTURE = "capture"
    VOID = "void"
    REFUND = "refund"

class FailureCode(str, Enum):
    INSUFFICIENT_FUNDS = "insufficient_funds"
    CARD_DECLINED = "card_declined"
    EXPIRED_CARD = "expired_card"
    INCORRECT_CVC = "incorrect_cvc"
    PROCESSING_ERROR = "processing_error"
    INVALID_AMOUNT = "invalid_amount"
    ALREADY_CAPTURED = "already_captured"
    ALREADY_VOIDED = "already_voided"
    CANNOT_VOID_CAPTURED = "cannot_void_captured"
