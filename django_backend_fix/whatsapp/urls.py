"""
URL Configuration for WhatsApp app
Ensure this endpoint is properly routed
"""

from django.urls import path
from . import views

app_name = 'whatsapp'

urlpatterns = [
    # ... other URLs ...
    path('products/get-suggestions/', views.get_product_suggestions, name='get_product_suggestions'),
    # ... other URLs ...
]

