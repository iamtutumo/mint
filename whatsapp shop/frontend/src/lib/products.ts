import { Product } from './types';

export const sampleProducts: Product[] = [
  {
    id: 'prod-1',
    name: 'Premium Leather Bag',
    description: 'Handcrafted genuine leather messenger bag with brass hardware',
    price: 149.99,
    type: 'physical',
    image: 'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=400&h=400&fit=crop',
    category: 'Accessories',
    inStock: true,
  },
  {
    id: 'prod-2',
    name: 'UI Design Masterclass',
    description: 'Complete video course with 40+ lessons on modern UI design',
    price: 79.00,
    type: 'digital',
    image: 'https://images.unsplash.com/photo-1611532736597-de2d4265fba3?w=400&h=400&fit=crop',
    category: 'Courses',
    downloadUrl: '/downloads/ui-masterclass.zip',
  },
  {
    id: 'prod-3',
    name: 'Business Consultation',
    description: '1-hour video call with expert business strategy advisor',
    price: 120.00,
    type: 'service',
    image: 'https://images.unsplash.com/photo-1553028826-f4804a6dba3b?w=400&h=400&fit=crop',
    category: 'Consulting',
    duration: 60,
  },
  {
    id: 'prod-4',
    name: 'Wireless Headphones',
    description: 'Premium noise-canceling headphones with 30hr battery',
    price: 299.00,
    type: 'physical',
    image: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400&h=400&fit=crop',
    category: 'Electronics',
    inStock: true,
  },
  {
    id: 'prod-5',
    name: 'Brand Identity Kit',
    description: 'Complete logo, color palette, typography & brand guidelines',
    price: 199.00,
    type: 'digital',
    image: 'https://images.unsplash.com/photo-1626785774573-4b799315345d?w=400&h=400&fit=crop',
    category: 'Design Assets',
    downloadUrl: '/downloads/brand-kit.zip',
  },
  {
    id: 'prod-6',
    name: 'Photography Session',
    description: '2-hour professional portrait photography session',
    price: 250.00,
    type: 'service',
    image: 'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?w=400&h=400&fit=crop',
    category: 'Photography',
    duration: 120,
  },
];

export function getProductById(id: string): Product | undefined {
  return sampleProducts.find(p => p.id === id);
}

export function getProductsByType(type: Product['type']): Product[] {
  return sampleProducts.filter(p => p.type === type);
}
