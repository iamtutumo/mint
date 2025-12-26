import { Package, Download, Calendar, LayoutGrid } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { ProductType } from '@/lib/types';
import { cn } from '@/lib/utils';

interface ProductFiltersProps {
  activeFilter: ProductType | 'all';
  onFilterChange: (filter: ProductType | 'all') => void;
}

const filters = [
  { value: 'all' as const, label: 'All Products', icon: LayoutGrid },
  { value: 'physical' as const, label: 'Physical', icon: Package },
  { value: 'digital' as const, label: 'Digital', icon: Download },
  { value: 'service' as const, label: 'Services', icon: Calendar },
];

export function ProductFilters({ activeFilter, onFilterChange }: ProductFiltersProps) {
  return (
    <div className="flex flex-wrap gap-2 justify-center">
      {filters.map(filter => {
        const Icon = filter.icon;
        const isActive = activeFilter === filter.value;
        
        return (
          <Button
            key={filter.value}
            variant={isActive ? "mercury" : "glass"}
            size="sm"
            onClick={() => onFilterChange(filter.value)}
            className={cn(
              "flex items-center gap-2",
              isActive && "glow-primary"
            )}
          >
            <Icon className="w-4 h-4" />
            {filter.label}
          </Button>
        );
      })}
    </div>
  );
}
