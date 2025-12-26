import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Send, Mail, Phone, User } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { CartItem, CustomerInfo, ServiceBooking } from '@/lib/types';
import { clearCart, getCartTotal } from '@/lib/cart';
import { toast } from 'sonner';

interface CheckoutFormProps {
  items: CartItem[];
}

export function CheckoutForm({ items }: CheckoutFormProps) {
  const navigate = useNavigate();
  const [customerInfo, setCustomerInfo] = useState<CustomerInfo>({
    name: '',
    phone: '',
    email: '',
  });
  const [isSubmitting, setIsSubmitting] = useState(false);

  const isMobile = /Mobi|Android/i.test(navigator.userAgent);
  const total = getCartTotal();

  const serviceItems = items.filter(i => i.type === 'service');
  const allServicesBooked = serviceItems.every(i => i.serviceDate && i.serviceTime);

  const generateOrderMessage = () => {
    const orderId = `ORD-${Date.now().toString(36).toUpperCase()}`;
    
    let message = `🛒 *New Order: ${orderId}*\n\n`;
    message += `👤 *Customer:* ${customerInfo.name}\n`;
    message += `📱 *Phone:* ${customerInfo.phone}\n`;
    if (customerInfo.email) {
      message += `📧 *Email:* ${customerInfo.email}\n`;
    }
    message += `\n📦 *Items:*\n`;
    
    items.forEach(item => {
      message += `• ${item.name} x${item.quantity} - $${(item.price * item.quantity).toFixed(2)}`;
      if (item.type === 'service' && item.serviceDate && item.serviceTime) {
        message += `\n  📅 Booking: ${item.serviceDate} at ${item.serviceTime}`;
      }
      if (item.type === 'digital') {
        message += ` (Digital)`;
      }
      message += `\n`;
    });
    
    message += `\n💰 *Total:* $${total.toFixed(2)}`;
    
    return { orderId, message };
  };

  const handleWhatsAppCheckout = () => {
    if (!customerInfo.name || !customerInfo.phone) {
      toast.error('Please fill in your name and phone number');
      return;
    }

    if (serviceItems.length > 0 && !allServicesBooked) {
      toast.error('Please select date & time for all service bookings');
      return;
    }

    setIsSubmitting(true);
    const { orderId, message } = generateOrderMessage();
    
    // Store order for status tracking
    const order = {
      id: orderId,
      items,
      customer: customerInfo,
      bookings: serviceItems.map(i => ({
        productId: i.id,
        date: i.serviceDate!,
        time: i.serviceTime!,
      })),
      status: 'pending',
      createdAt: new Date().toISOString(),
      totalAmount: total,
      paymentConfirmed: false,
    };
    
    const orders = JSON.parse(localStorage.getItem('mercury_orders') || '[]');
    orders.push(order);
    localStorage.setItem('mercury_orders', JSON.stringify(orders));

    clearCart();
    
    // Replace with your WhatsApp business number
    const whatsappNumber = '1234567890';
    const whatsappUrl = `https://wa.me/${whatsappNumber}?text=${encodeURIComponent(message)}`;
    
    window.open(whatsappUrl, '_blank');
    
    toast.success('Order placed! Redirecting to WhatsApp...');
    navigate(`/order-status?id=${orderId}`);
  };

  const handleEmailCheckout = () => {
    if (!customerInfo.name || !customerInfo.phone || !customerInfo.email) {
      toast.error('Please fill in all fields including email');
      return;
    }

    if (serviceItems.length > 0 && !allServicesBooked) {
      toast.error('Please select date & time for all service bookings');
      return;
    }

    setIsSubmitting(true);
    const { orderId } = generateOrderMessage();
    
    const order = {
      id: orderId,
      items,
      customer: customerInfo,
      bookings: serviceItems.map(i => ({
        productId: i.id,
        date: i.serviceDate!,
        time: i.serviceTime!,
      })),
      status: 'pending',
      createdAt: new Date().toISOString(),
      totalAmount: total,
      paymentConfirmed: false,
    };
    
    const orders = JSON.parse(localStorage.getItem('mercury_orders') || '[]');
    orders.push(order);
    localStorage.setItem('mercury_orders', JSON.stringify(orders));

    clearCart();
    
    toast.success('Order placed! You will receive email confirmation shortly.');
    navigate(`/order-status?id=${orderId}`);
  };

  return (
    <div className="bg-card rounded-2xl shadow-soft p-6">
      <h2 className="font-display font-semibold text-xl mb-6">Customer Information</h2>
      
      <div className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="name" className="flex items-center gap-2">
            <User className="w-4 h-4 text-muted-foreground" />
            Full Name
          </Label>
          <Input
            id="name"
            placeholder="John Doe"
            value={customerInfo.name}
            onChange={(e) => setCustomerInfo(prev => ({ ...prev, name: e.target.value }))}
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="phone" className="flex items-center gap-2">
            <Phone className="w-4 h-4 text-muted-foreground" />
            Phone Number
          </Label>
          <Input
            id="phone"
            type="tel"
            placeholder="+1 (555) 123-4567"
            value={customerInfo.phone}
            onChange={(e) => setCustomerInfo(prev => ({ ...prev, phone: e.target.value }))}
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="email" className="flex items-center gap-2">
            <Mail className="w-4 h-4 text-muted-foreground" />
            Email {!isMobile && <span className="text-muted-foreground">(required)</span>}
          </Label>
          <Input
            id="email"
            type="email"
            placeholder="john@example.com"
            value={customerInfo.email}
            onChange={(e) => setCustomerInfo(prev => ({ ...prev, email: e.target.value }))}
          />
        </div>
      </div>

      {/* Order Summary */}
      <div className="mt-6 pt-6 border-t border-border">
        <div className="flex justify-between items-center mb-4">
          <span className="text-muted-foreground">Subtotal</span>
          <span className="font-semibold">${total.toFixed(2)}</span>
        </div>
        <div className="flex justify-between items-center mb-6">
          <span className="font-display font-semibold text-lg">Total</span>
          <span className="font-display font-bold text-2xl text-primary">${total.toFixed(2)}</span>
        </div>

        <div className="space-y-3">
          {isMobile ? (
            <Button 
              variant="mercury" 
              size="lg" 
              className="w-full"
              onClick={handleWhatsAppCheckout}
              disabled={isSubmitting}
            >
              <Send className="w-5 h-5 mr-2" />
              Checkout via WhatsApp
            </Button>
          ) : (
            <>
              <Button 
                variant="mercury" 
                size="lg" 
                className="w-full"
                onClick={handleWhatsAppCheckout}
                disabled={isSubmitting}
              >
                <Send className="w-5 h-5 mr-2" />
                Checkout via WhatsApp
              </Button>
              <Button 
                variant="outline" 
                size="lg" 
                className="w-full"
                onClick={handleEmailCheckout}
                disabled={isSubmitting}
              >
                <Mail className="w-5 h-5 mr-2" />
                Checkout via Email
              </Button>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
