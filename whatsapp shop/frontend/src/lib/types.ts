export type ProductType = 'physical' | 'digital' | 'service';

export interface Product {
  id: string;
  name: string;
  description: string;
  price: number;
  type: ProductType;
  image: string;
  category: string;
  inStock?: boolean;
  downloadUrl?: string; // For digital products
  duration?: number; // For services (in minutes)
}

export interface CartItem extends Product {
  quantity: number;
  serviceDate?: string;
  serviceTime?: string;
}

export interface CustomerInfo {
  name: string;
  phone: string;
  email?: string;
}

export interface ServiceBooking {
  productId: string;
  date: string;
  time: string;
}

export interface Order {
  id: string;
  items: CartItem[];
  customer: CustomerInfo;
  bookings: ServiceBooking[];
  status: 'pending' | 'confirmed' | 'processing' | 'completed' | 'cancelled';
  createdAt: string;
  totalAmount: number;
  paymentConfirmed: boolean;
}
