import apiClient from './client';
import { CartItem } from '../types';

export const getCart = async (): Promise<CartItem[]> => {
  try {
    const response = await apiClient.get('/cart');
    return response.data;
  } catch (error) {
    console.error('Error fetching cart:', error);
    throw error;
  }
};

export const addToCart = async (productId: string, quantity: number = 1): Promise<CartItem> => {
  try {
    const response = await apiClient.post('/cart/items', { productId, quantity });
    return response.data;
  } catch (error) {
    console.error('Error adding to cart:', error);
    throw error;
  }
};

export const updateCartItem = async (itemId: string, quantity: number): Promise<CartItem> => {
  try {
    const response = await apiClient.patch(`/cart/items/${itemId}`, { quantity });
    return response.data;
  } catch (error) {
    console.error('Error updating cart item:', error);
    throw error;
  }
};

export const removeFromCart = async (itemId: string): Promise<void> => {
  try {
    await apiClient.delete(`/cart/items/${itemId}`);
  } catch (error) {
    console.error('Error removing from cart:', error);
    throw error;
  }
};

export const clearCart = async (): Promise<void> => {
  try {
    await apiClient.delete('/cart');
  } catch (error) {
    console.error('Error clearing cart:', error);
    throw error;
  }
};
