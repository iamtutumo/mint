import { createContext, useContext, ReactNode, useState, useEffect } from 'react';
import { CartItem, Product } from '@/lib/types';
import { getCart as fetchCart, addToCart as addItemToCart, updateCartItem, removeFromCart as removeItemFromCart, clearCart as clearUserCart } from '@/lib/api/cart';

type CartContextType = {
  items: CartItem[];
  loading: boolean;
  error: string | null;
  addToCart: (product: Product, quantity?: number) => Promise<void>;
  updateCart: (itemId: string, quantity: number) => Promise<void>;
  removeFromCart: (itemId: string) => Promise<void>;
  clearCart: () => Promise<void>;
  cartCount: number;
  cartTotal: number;
};

const CartContext = createContext<CartContextType | undefined>(undefined);

export function CartProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<CartItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchCartData = async () => {
    try {
      setLoading(true);
      const cartData = await fetchCart();
      setItems(cartData);
    } catch (err) {
      setError('Failed to load cart');
      console.error('Cart error:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCartData();
  }, []);

  const addToCart = async (product: Product, quantity: number = 1) => {
    try {
      const newItem = await addItemToCart(product.id, quantity);
      setItems(prev => {
        const existingItem = prev.find(item => item.product.id === product.id);
        if (existingItem) {
          return prev.map(item =>
            item.product.id === product.id
              ? { ...item, quantity: item.quantity + quantity }
              : item
          );
        }
        return [...prev, newItem];
      });
    } catch (err) {
      setError('Failed to add item to cart');
      throw err;
    }
  };

  const updateCart = async (itemId: string, quantity: number) => {
    try {
      if (quantity <= 0) {
        await removeFromCart(itemId);
        return;
      }
      await updateCartItem(itemId, quantity);
      setItems(prev =>
        prev.map(item =>
          item.id === itemId ? { ...item, quantity } : item
        )
      );
    } catch (err) {
      setError('Failed to update cart');
      throw err;
    }
  };

  const removeFromCart = async (itemId: string) => {
    try {
      await removeItemFromCart(itemId);
      setItems(prev => prev.filter(item => item.id !== itemId));
    } catch (err) {
      setError('Failed to remove item from cart');
      throw err;
    }
  };

  const clearCart = async () => {
    try {
      await clearUserCart();
      setItems([]);
    } catch (err) {
      setError('Failed to clear cart');
      throw err;
    }
  };

  const cartCount = items.reduce((sum, item) => sum + item.quantity, 0);
  const cartTotal = items.reduce(
    (sum, item) => sum + item.product.price * item.quantity,
    0
  );

  return (
    <CartContext.Provider
      value={{
        items,
        loading,
        error,
        addToCart,
        updateCart,
        removeFromCart,
        clearCart,
        cartCount,
        cartTotal,
      }}
    >
      {children}
    </CartContext.Provider>
  );
}

export const useCart = () => {
  const context = useContext(CartContext);
  if (context === undefined) {
    throw new Error('useCart must be used within a CartProvider');
  }
  return context;
};
