import { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { Helmet } from 'react-helmet-async';
import { ShoppingCart, ArrowLeft } from 'lucide-react';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';
import { CartItem } from '@/components/cart/CartItem';
import { ServicePicker } from '@/components/cart/ServicePicker';
import { CheckoutForm } from '@/components/cart/CheckoutForm';
import { Button } from '@/components/ui/button';
import { getCart } from '@/lib/cart';
import { CartItem as CartItemType } from '@/lib/types';

const Cart = () => {
  const [items, setItems] = useState<CartItemType[]>([]);

  const refreshCart = useCallback(() => {
    setItems(getCart());
  }, []);

  useEffect(() => {
    refreshCart();
    window.addEventListener('cartUpdated', refreshCart);
    return () => window.removeEventListener('cartUpdated', refreshCart);
  }, [refreshCart]);

  const serviceItems = items.filter(i => i.type === 'service');

  return (
    <>
      <Helmet>
        <title>Your Cart | Mercury</title>
        <meta name="description" content="Review your cart, book services, and checkout via WhatsApp or email." />
      </Helmet>

      <div className="min-h-screen flex flex-col">
        <Header />
        
        <main className="flex-1 pt-28 pb-16">
          <div className="container max-w-6xl mx-auto px-4">
            {/* Back Link */}
            <Link to="/" className="inline-flex items-center gap-2 text-muted-foreground hover:text-foreground transition-colors mb-8">
              <ArrowLeft className="w-4 h-4" />
              Continue Shopping
            </Link>

            <h1 className="font-display font-bold text-3xl mb-8">Your Cart</h1>

            {items.length === 0 ? (
              <div className="text-center py-16">
                <div className="w-20 h-20 rounded-full bg-muted flex items-center justify-center mx-auto mb-6">
                  <ShoppingCart className="w-10 h-10 text-muted-foreground" />
                </div>
                <h2 className="font-display font-semibold text-xl mb-2">Your cart is empty</h2>
                <p className="text-muted-foreground mb-6">Add some products to get started!</p>
                <Button variant="mercury" asChild>
                  <Link to="/">Browse Products</Link>
                </Button>
              </div>
            ) : (
              <div className="grid lg:grid-cols-5 gap-8">
                {/* Cart Items */}
                <div className="lg:col-span-3 space-y-4">
                  {items.map(item => (
                    <div key={item.id}>
                      <CartItem item={item} onUpdate={refreshCart} />
                      
                      {/* Service Booking Picker */}
                      {item.type === 'service' && (
                        <ServicePicker item={item} onUpdate={refreshCart} />
                      )}
                    </div>
                  ))}

                  {/* Service Booking Notice */}
                  {serviceItems.length > 0 && (
                    <div className="p-4 bg-accent rounded-xl text-sm">
                      <p className="text-accent-foreground">
                        💡 <strong>Service bookings:</strong> Select your preferred date and time for each service above. 
                        Bookings are subject to availability confirmation.
                      </p>
                    </div>
                  )}
                </div>

                {/* Checkout Form */}
                <div className="lg:col-span-2">
                  <div className="sticky top-28">
                    <CheckoutForm items={items} />
                  </div>
                </div>
              </div>
            )}
          </div>
        </main>

        <Footer />
      </div>
    </>
  );
};

export default Cart;
