import { useState, useMemo } from 'react';
import { Helmet } from 'react-helmet-async';
import { Sparkles } from 'lucide-react';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';
import { ProductGrid } from '@/components/products/ProductGrid';
import { ProductFilters } from '@/components/products/ProductFilters';
import { sampleProducts } from '@/lib/products';
import { ProductType } from '@/lib/types';

const Index = () => {
  const [filter, setFilter] = useState<ProductType | 'all'>('all');

  const filteredProducts = useMemo(() => {
    if (filter === 'all') return sampleProducts;
    return sampleProducts.filter(p => p.type === filter);
  }, [filter]);

  return (
    <>
      <Helmet>
        <title>Mercury | Modern Commerce Platform</title>
        <meta name="description" content="Shop physical products, digital downloads, and book services. Seamless checkout via WhatsApp or email." />
      </Helmet>

      <div className="min-h-screen flex flex-col">
        <Header />
        
        <main className="flex-1 pt-28 pb-16">
          {/* Hero Section */}
          <section className="container max-w-6xl mx-auto px-4 mb-16">
            <div className="text-center max-w-3xl mx-auto">
              <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-accent text-accent-foreground text-sm font-medium mb-6 animate-slide-up">
                <Sparkles className="w-4 h-4" />
                Physical • Digital • Services
              </div>
              
              <h1 className="font-display font-bold text-4xl sm:text-5xl lg:text-6xl text-foreground mb-6 animate-slide-up-delay-1">
                Shop Smarter with{' '}
                <span className="mercury-gradient bg-clip-text text-transparent">Mercury</span>
              </h1>
              
              <p className="text-lg text-muted-foreground max-w-2xl mx-auto animate-slide-up-delay-2">
                Browse our curated collection of products and services. 
                Book appointments, download digital goods, or order physical items — 
                all with seamless WhatsApp checkout.
              </p>
            </div>
          </section>

          {/* Filters */}
          <section className="container max-w-6xl mx-auto px-4 mb-12">
            <ProductFilters activeFilter={filter} onFilterChange={setFilter} />
          </section>

          {/* Products Grid */}
          <section className="container max-w-6xl mx-auto px-4">
            <ProductGrid products={filteredProducts} />
            
            {filteredProducts.length === 0 && (
              <div className="text-center py-16">
                <p className="text-muted-foreground">No products found in this category.</p>
              </div>
            )}
          </section>
        </main>

        <Footer />
      </div>
    </>
  );
};

export default Index;
