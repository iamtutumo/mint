import { useState, useEffect } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { Helmet } from 'react-helmet-async';
import { ArrowLeft, Search, Package } from 'lucide-react';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';
import { OrderStatusCard } from '@/components/orders/OrderStatusCard';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Order } from '@/lib/types';

const OrderStatus = () => {
  const [searchParams] = useSearchParams();
  const [orderId, setOrderId] = useState(searchParams.get('id') || '');
  const [order, setOrder] = useState<Order | null>(null);
  const [searched, setSearched] = useState(false);

  useEffect(() => {
    const id = searchParams.get('id');
    if (id) {
      setOrderId(id);
      searchOrder(id);
    }
  }, [searchParams]);

  const searchOrder = (id: string) => {
    const orders: Order[] = JSON.parse(localStorage.getItem('mercury_orders') || '[]');
    const found = orders.find(o => o.id.toLowerCase() === id.toLowerCase());
    setOrder(found || null);
    setSearched(true);
  };

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    searchOrder(orderId);
  };

  return (
    <>
      <Helmet>
        <title>Order Status | Mercury</title>
        <meta name="description" content="Track your order status and access digital downloads." />
      </Helmet>

      <div className="min-h-screen flex flex-col">
        <Header />
        
        <main className="flex-1 pt-28 pb-16">
          <div className="container max-w-2xl mx-auto px-4">
            {/* Back Link */}
            <Link to="/" className="inline-flex items-center gap-2 text-muted-foreground hover:text-foreground transition-colors mb-8">
              <ArrowLeft className="w-4 h-4" />
              Continue Shopping
            </Link>

            <h1 className="font-display font-bold text-3xl mb-2">Order Status</h1>
            <p className="text-muted-foreground mb-8">
              Track your order and access digital downloads
            </p>

            {/* Search Form */}
            <form onSubmit={handleSearch} className="flex gap-3 mb-8">
              <Input
                placeholder="Enter your order ID (e.g., ORD-XXXXX)"
                value={orderId}
                onChange={(e) => setOrderId(e.target.value)}
                className="flex-1"
              />
              <Button type="submit" variant="mercury">
                <Search className="w-4 h-4 mr-2" />
                Track
              </Button>
            </form>

            {/* Results */}
            {order ? (
              <OrderStatusCard order={order} />
            ) : searched ? (
              <div className="text-center py-16 bg-card rounded-2xl shadow-soft">
                <div className="w-20 h-20 rounded-full bg-muted flex items-center justify-center mx-auto mb-6">
                  <Package className="w-10 h-10 text-muted-foreground" />
                </div>
                <h2 className="font-display font-semibold text-xl mb-2">Order Not Found</h2>
                <p className="text-muted-foreground mb-6">
                  We couldn't find an order with ID "{orderId}".
                  <br />
                  Please check your order ID and try again.
                </p>
                <Button variant="outline" onClick={() => { setOrderId(''); setSearched(false); }}>
                  Clear Search
                </Button>
              </div>
            ) : (
              <div className="text-center py-16 bg-card rounded-2xl shadow-soft">
                <div className="w-20 h-20 rounded-full bg-accent flex items-center justify-center mx-auto mb-6">
                  <Search className="w-10 h-10 text-accent-foreground" />
                </div>
                <h2 className="font-display font-semibold text-xl mb-2">Track Your Order</h2>
                <p className="text-muted-foreground">
                  Enter your order ID above to check status
                  <br />
                  and access any digital downloads.
                </p>
              </div>
            )}
          </div>
        </main>

        <Footer />
      </div>
    </>
  );
};

export default OrderStatus;
