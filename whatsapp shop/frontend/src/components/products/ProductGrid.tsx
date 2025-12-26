import { Product } from '@/lib/types';
import { ProductCard } from './ProductCard';

interface ProductGridProps {
  products: Product[];
}

export function ProductGrid({ products }: ProductGridProps) {
  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
      {products.map((product, index) => (
        <div 
          key={product.id} 
          style={{ animationDelay: `${index * 0.1}s` }}
          className="animate-slide-up opacity-0"
        >
          <ProductCard product={product} />
        </div>
      ))}
    </div>
  );
}
