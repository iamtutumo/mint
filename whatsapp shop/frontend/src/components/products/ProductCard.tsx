import { useState } from 'react';
import { Package, Download, Calendar, Clock, Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Product } from '@/lib/types';
import { addToCart } from '@/lib/cart';
import { toast } from 'sonner';
import { formatUGX } from '@/lib/utils/currency';

interface ProductCardProps {
  product: Product;
}

const typeIcons = {
  physical: Package,
  digital: Download,
  service: Calendar,
};

export function ProductCard({ product }: ProductCardProps) {
  const TypeIcon = typeIcons[product.type];

  const [isAdding, setIsAdding] = useState(false);

  const handleAddToCart = async () => {
    try {
      setIsAdding(true);
      await addToCart(product);
      toast.success(`${product.name} added to cart!`, {
        description: product.type === 'service' 
          ? 'Select date & time during checkout' 
          : undefined,
      });
    } catch (error) {
      console.error('Failed to add to cart:', error);
      toast.error('Failed to add item to cart. Please try again.');
    } finally {
      setIsAdding(false);
    }
  };

  return (
    <article className="group bg-card rounded-2xl overflow-hidden shadow-soft hover:shadow-elevated transition-all duration-300 animate-scale-in">
      {/* Image Container */}
      <div className="relative aspect-square overflow-hidden">
        <img 
          src={product.image} 
          alt={product.name}
          className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
        />
        
        {/* Type Badge */}
        <Badge 
          variant={product.type} 
          className="absolute top-3 left-3 flex items-center gap-1"
        >
          <TypeIcon className="w-3 h-3" />
          {product.type.charAt(0).toUpperCase() + product.type.slice(1)}
        </Badge>

        {/* Service Duration */}
        {product.type === 'service' && product.duration && (
          <div className="absolute top-3 right-3 bg-card/90 backdrop-blur-sm rounded-full px-2.5 py-1 flex items-center gap-1 text-xs font-medium">
            <Clock className="w-3 h-3 text-service" />
            {product.duration} min
          </div>
        )}
      </div>

      {/* Content */}
      <div className="p-5">
        <p className="text-xs text-muted-foreground font-medium uppercase tracking-wider mb-1">
          {product.category}
        </p>
        <h3 className="font-display font-semibold text-lg mb-2 group-hover:text-primary transition-colors">
          {product.name}
        </h3>
        <p className="text-sm text-muted-foreground line-clamp-2 mb-4">
          {product.description}
        </p>

        <div className="flex items-center justify-between">
          <p className="text-2xl font-bold text-foreground">{formatUGX(product.price)}</p>
          <Button 
            onClick={handleAddToCart}
            className="w-full"
            variant="default"
            disabled={isAdding}
          >
            {isAdding ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                Adding...
              </>
            ) : (
              'Add to Cart'
            )}
          </Button>
        </div>
      </div>
    </article>
  );
}
