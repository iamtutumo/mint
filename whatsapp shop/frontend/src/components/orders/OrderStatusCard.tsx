import { CheckCircle, Clock, Package, XCircle, Download, Calendar } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Order } from '@/lib/types';
import { cn } from '@/lib/utils';

interface OrderStatusCardProps {
  order: Order;
}

const statusConfig = {
  pending: {
    icon: Clock,
    label: 'Pending',
    color: 'bg-amber-100 text-amber-700',
    description: 'Your order is awaiting confirmation',
  },
  confirmed: {
    icon: CheckCircle,
    label: 'Confirmed',
    color: 'bg-primary/10 text-primary',
    description: 'Order confirmed! Processing soon',
  },
  processing: {
    icon: Package,
    label: 'Processing',
    color: 'bg-blue-100 text-blue-700',
    description: 'Your order is being prepared',
  },
  completed: {
    icon: CheckCircle,
    label: 'Completed',
    color: 'bg-green-100 text-green-700',
    description: 'Order complete! Thank you',
  },
  cancelled: {
    icon: XCircle,
    label: 'Cancelled',
    color: 'bg-destructive/10 text-destructive',
    description: 'Order was cancelled',
  },
};

export function OrderStatusCard({ order }: OrderStatusCardProps) {
  const status = statusConfig[order.status];
  const StatusIcon = status.icon;

  const digitalItems = order.items.filter(i => i.type === 'digital');
  const serviceItems = order.items.filter(i => i.type === 'service');

  return (
    <div className="bg-card rounded-2xl shadow-soft overflow-hidden">
      {/* Status Header */}
      <div className={cn("p-6", status.color.replace('text-', 'bg-').split(' ')[0] + '/10')}>
        <div className="flex items-center gap-4">
          <div className={cn("w-12 h-12 rounded-full flex items-center justify-center", status.color)}>
            <StatusIcon className="w-6 h-6" />
          </div>
          <div>
            <p className="text-sm text-muted-foreground">Order {order.id}</p>
            <h2 className="font-display font-semibold text-xl">{status.label}</h2>
            <p className="text-sm text-muted-foreground">{status.description}</p>
          </div>
        </div>
      </div>

      {/* Order Details */}
      <div className="p-6">
        <div className="space-y-4">
          <div>
            <h3 className="font-semibold mb-3">Order Items</h3>
            <div className="space-y-3">
              {order.items.map(item => (
                <div key={item.id} className="flex items-center gap-3 p-3 bg-muted/50 rounded-lg">
                  <img 
                    src={item.image} 
                    alt={item.name}
                    className="w-12 h-12 rounded-lg object-cover"
                  />
                  <div className="flex-1 min-w-0">
                    <p className="font-medium text-sm truncate">{item.name}</p>
                    <div className="flex items-center gap-2">
                      <Badge variant={item.type} className="text-xs">
                        {item.type}
                      </Badge>
                      <span className="text-xs text-muted-foreground">x{item.quantity}</span>
                    </div>
                  </div>
                  <span className="font-semibold">${(item.price * item.quantity).toFixed(2)}</span>
                </div>
              ))}
            </div>
          </div>

          {/* Service Bookings */}
          {serviceItems.length > 0 && (
            <div>
              <h3 className="font-semibold mb-3 flex items-center gap-2">
                <Calendar className="w-4 h-4 text-service" />
                Booked Sessions
              </h3>
              <div className="space-y-2">
                {serviceItems.map(item => {
                  const booking = order.bookings.find(b => b.productId === item.id);
                  return (
                    <div key={item.id} className="p-3 bg-service/10 rounded-lg">
                      <p className="font-medium text-sm">{item.name}</p>
                      {booking && (
                        <p className="text-sm text-muted-foreground mt-1">
                          📅 {booking.date} at {booking.time}
                        </p>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* Digital Downloads */}
          {digitalItems.length > 0 && order.paymentConfirmed && (
            <div>
              <h3 className="font-semibold mb-3 flex items-center gap-2">
                <Download className="w-4 h-4 text-digital" />
                Digital Downloads
              </h3>
              <div className="space-y-2">
                {digitalItems.map(item => (
                  <Button 
                    key={item.id}
                    variant="outline" 
                    className="w-full justify-start"
                    asChild
                  >
                    <a href={item.downloadUrl} target="_blank" rel="noopener noreferrer">
                      <Download className="w-4 h-4 mr-2 text-digital" />
                      Download {item.name}
                    </a>
                  </Button>
                ))}
              </div>
            </div>
          )}

          {digitalItems.length > 0 && !order.paymentConfirmed && (
            <div className="p-4 bg-amber-50 border border-amber-200 rounded-lg">
              <p className="text-sm text-amber-700">
                ⏳ Digital downloads will be available after payment confirmation.
              </p>
            </div>
          )}

          {/* Total */}
          <div className="pt-4 border-t border-border">
            <div className="flex justify-between items-center">
              <span className="font-display font-semibold">Total</span>
              <span className="font-display font-bold text-2xl text-primary">
                ${order.totalAmount.toFixed(2)}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
