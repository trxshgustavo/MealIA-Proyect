import os
import stripe
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
import security
import models

router = APIRouter(prefix="/payments", tags=["payments"])

# Initialize Stripe
# WARNING: This uses a TEST key. Replace with env var in production.
stripe.api_key = os.getenv("STRIPE_SECRET_KEY")


class PaymentIntentRequest(BaseModel):
    amount: int
    currency: str = "usd"


class PaymentIntentResponse(BaseModel):
    clientSecret: str


@router.post("/create-payment-intent", response_model=PaymentIntentResponse)
def create_payment_intent(
    req: PaymentIntentRequest,
    current_user: models.User = Depends(security.get_current_user),
):
    try:
        # Create a PaymentIntent with the order amount and currency
        intent = stripe.PaymentIntent.create(
            amount=req.amount,
            currency=req.currency,
            automatic_payment_methods={
                "enabled": True,
            },
            metadata={"user_id": current_user.id, "email": current_user.email},
        )
        return {"clientSecret": intent.client_secret}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
