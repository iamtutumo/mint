import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";

import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-lg text-sm font-medium ring-offset-background transition-all duration-300 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground hover:bg-primary/90 shadow-[0_4px_24px_-4px_hsl(200_25%_15%/0.08)] hover:shadow-[0_12px_48px_-8px_hsl(200_25%_15%/0.12)]",
        destructive: "bg-destructive text-destructive-foreground hover:bg-destructive/90",
        outline: "border-2 border-primary bg-transparent text-primary hover:bg-primary hover:text-primary-foreground",
        secondary: "bg-secondary text-secondary-foreground hover:bg-secondary/80 shadow-[0_4px_24px_-4px_hsl(200_25%_15%/0.08)]",
        ghost: "hover:bg-accent hover:text-accent-foreground",
        link: "text-primary underline-offset-4 hover:underline",
        mercury: "bg-gradient-to-br from-[hsl(173_58%_39%)] to-[hsl(180_45%_50%)] text-[hsl(0_0%_100%)] shadow-[0_4px_24px_-4px_hsl(200_25%_15%/0.08)] hover:shadow-[0_12px_48px_-8px_hsl(200_25%_15%/0.12)] hover:scale-[1.02] active:scale-[0.98]",
        amber: "bg-gradient-to-br from-[hsl(38_92%_50%)] to-[hsl(28_90%_55%)] text-[hsl(200_25%_10%)] shadow-[0_4px_24px_-4px_hsl(200_25%_15%/0.08)] hover:shadow-[0_12px_48px_-8px_hsl(200_25%_15%/0.12)] hover:scale-[1.02] active:scale-[0.98]",
        glass: "bg-[hsl(0_0%_100%/0.8)] backdrop-blur-sm border border-border/50 text-foreground hover:bg-card shadow-[0_4px_24px_-4px_hsl(200_25%_15%/0.08)] hover:shadow-[0_12px_48px_-8px_hsl(200_25%_15%/0.12)]",
      },
      size: {
        default: "h-11 px-5 py-2",
        sm: "h-9 rounded-md px-4",
        lg: "h-12 rounded-lg px-8 text-base",
        xl: "h-14 rounded-xl px-10 text-lg font-semibold",
        icon: "h-10 w-10",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  },
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : "button";
    return <Comp className={cn(buttonVariants({ variant, size, className }))} ref={ref} {...props} />;
  },
);
Button.displayName = "Button";

export { Button, buttonVariants };
