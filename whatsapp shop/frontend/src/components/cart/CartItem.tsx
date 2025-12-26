import { Minus, Plus, Trash2, Package, Download, Calendar } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { CartItem as CartItemType } from '@/lib/types';
import { updateQuantity, removeFromCart } from '@/lib/cart';

interface CartItemProps {
  item: CartItemType;
  onUpdate: () => void;
}

const typeIcons = {
  physical: Package,
  digital: Download,
  service: Calendar,
};

export function CartItem({ item, onUpdate }: CartItemProps) {
  const TypeIcon = typeIcons[item.type];

  const handleQuantityChange = (delta: number) => {
    updateQuantity(item.id, item.quantity + delta);
    onUpdate();
  };

  const handleRemove = () => {
    removeFromCart(item.id);
    onUpdate();
  };

  return (
    <div className="flex gap-4 p-4 bg-card rounded-xl shadow-soft">
      {/* Image */}
      <div className="w-20 h-20 rounded-lg overflow-hidden flex-shrink-0">
        <img 
          src={item.image} 
          alt={item.name}
          className="w-full h-full object-cover"
        />
      </div>

      {/* Details */}
      <div className="flex-1 min-w-0">
        <div className="flex items-start justify-between gap-2">
          <div>
            <Badge variant={item.type} className="mb-1 flex items-center gap-1 w-fit">
              <TypeIcon className="w-3 h-3" />
              {item.type}
            </Badge>
            <h3 className="font-display font-semibold text-sm line-clamp-1">{item.name}</h3>
          </div>
          <Button 
            variant="ghost" 
            size="icon" 
            className="h-8 w-8 text-muted-foreground hover:text-destructive"
            onClick={handleRemove}
          >
            <Trash2 className="w-4 h-4" />
          </Button>
        </div>

        <div className="flex items-center justify-between mt-3">
          {/* Quantity Controls */}
          <div className="flex items-center gap-2">
            <Button 
              variant="outline" 
              size="icon" 
              className="h-8 w-8"
              onClick={() => handleQuantityChange(-1)}
              disabled={item.quantity <= 1}
            >
              <Minus className="w-3 h-3" />
            </Button>
            <span className="w-8 text-center font-medium">{item.quantity}</span>
            <Button 
              variant="outline" 
              size="icon" 
              className="h-8 w-8"
              onClick={() => handleQuantityChange(1)}
            >
              <Plus className="w-3 h-3" />
            </Button>
          </div>

          {/* Price */}
          <span className="font-display font-bold">
            ${(item.price * item.quantity).toFixed(2)}
          </span>
        </div>
      </div>
    </div>
  );
}
