import { useState } from "react";
import { Helmet } from "react-helmet-async";
import { useSearchParams } from "react-router-dom";
import { Star, Send, CheckCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { toast } from "@/hooks/use-toast";

const Survey = () => {
  const [searchParams] = useSearchParams();
  const orderId = searchParams.get("order");
  
  const [submitted, setSubmitted] = useState(false);
  const [rating, setRating] = useState(0);
  const [hoveredRating, setHoveredRating] = useState(0);
  const [feedback, setFeedback] = useState("");
  const [recommendation, setRecommendation] = useState("");
  const [improvement, setImprovement] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    if (rating === 0) {
      toast({
        title: "Please rate your experience",
        description: "Select a star rating before submitting",
        variant: "destructive",
      });
      return;
    }

    // Store survey response (would be sent to backend)
    const surveyData = {
      orderId,
      rating,
      recommendation,
      feedback,
      improvement,
      submittedAt: new Date().toISOString(),
    };
    
    console.log("Survey submitted:", surveyData);
    localStorage.setItem(`survey_${orderId}`, JSON.stringify(surveyData));
    
    setSubmitted(true);
    toast({
      title: "Thank you for your feedback!",
      description: "Your response helps us improve our service.",
    });
  };

  if (submitted) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center p-4">
        <Helmet>
          <title>Thank You | Mercury Commerce</title>
        </Helmet>
        <div className="max-w-md w-full text-center space-y-6">
          <div className="w-20 h-20 rounded-full bg-emerald-500/20 flex items-center justify-center mx-auto">
            <CheckCircle className="w-10 h-10 text-emerald-500" />
          </div>
          <h1 className="text-3xl font-display font-bold text-foreground">
            Thank You!
          </h1>
          <p className="text-muted-foreground">
            Your feedback is invaluable to us. We appreciate you taking the time to share your experience.
          </p>
          <Button variant="mercury" onClick={() => window.location.href = "/"}>
            Continue Shopping
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background py-12 px-4">
      <Helmet>
        <title>Customer Survey | Mercury Commerce</title>
        <meta name="description" content="Share your feedback and help us improve your shopping experience." />
        <meta name="robots" content="noindex, nofollow" />
      </Helmet>

      <div className="max-w-2xl mx-auto">
        <div className="text-center mb-10">
          <h1 className="text-4xl font-display font-bold text-foreground mb-4">
            How Was Your Experience?
          </h1>
          <p className="text-muted-foreground text-lg">
            Your feedback helps us serve you better
          </p>
          {orderId && (
            <p className="text-sm text-muted-foreground mt-2">
              Order: <span className="font-mono text-primary">{orderId}</span>
            </p>
          )}
        </div>

        <form onSubmit={handleSubmit} className="space-y-8">
          {/* Star Rating */}
          <div className="bg-card rounded-2xl p-8 border border-border/50 shadow-card">
            <Label className="text-lg font-semibold mb-4 block text-center">
              Rate your overall experience
            </Label>
            <div className="flex justify-center gap-2">
              {[1, 2, 3, 4, 5].map((star) => (
                <button
                  key={star}
                  type="button"
                  onClick={() => setRating(star)}
                  onMouseEnter={() => setHoveredRating(star)}
                  onMouseLeave={() => setHoveredRating(0)}
                  className="p-1 transition-transform hover:scale-110"
                >
                  <Star
                    className={`w-10 h-10 transition-colors ${
                      star <= (hoveredRating || rating)
                        ? "fill-amber-400 text-amber-400"
                        : "text-muted-foreground/30"
                    }`}
                  />
                </button>
              ))}
            </div>
            <p className="text-center text-sm text-muted-foreground mt-3">
              {rating === 0 && "Click to rate"}
              {rating === 1 && "Poor"}
              {rating === 2 && "Fair"}
              {rating === 3 && "Good"}
              {rating === 4 && "Very Good"}
              {rating === 5 && "Excellent!"}
            </p>
          </div>

          {/* Recommendation */}
          <div className="bg-card rounded-2xl p-8 border border-border/50 shadow-card">
            <Label className="text-lg font-semibold mb-4 block">
              Would you recommend us to a friend?
            </Label>
            <RadioGroup value={recommendation} onValueChange={setRecommendation}>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                {["Definitely", "Maybe", "Probably Not"].map((option) => (
                  <div key={option} className="flex items-center space-x-3">
                    <RadioGroupItem value={option.toLowerCase()} id={option} />
                    <Label htmlFor={option} className="cursor-pointer">
                      {option}
                    </Label>
                  </div>
                ))}
              </div>
            </RadioGroup>
          </div>

          {/* Feedback */}
          <div className="bg-card rounded-2xl p-8 border border-border/50 shadow-card">
            <Label htmlFor="feedback" className="text-lg font-semibold mb-4 block">
              What did you like most about your experience?
            </Label>
            <Textarea
              id="feedback"
              value={feedback}
              onChange={(e) => setFeedback(e.target.value)}
              placeholder="Tell us what made your experience great..."
              className="min-h-[100px] resize-none"
            />
          </div>

          {/* Improvement */}
          <div className="bg-card rounded-2xl p-8 border border-border/50 shadow-card">
            <Label htmlFor="improvement" className="text-lg font-semibold mb-4 block">
              How can we improve?
            </Label>
            <Textarea
              id="improvement"
              value={improvement}
              onChange={(e) => setImprovement(e.target.value)}
              placeholder="Any suggestions for how we can do better..."
              className="min-h-[100px] resize-none"
            />
          </div>

          <Button type="submit" variant="mercury" size="lg" className="w-full">
            <Send className="w-5 h-5 mr-2" />
            Submit Feedback
          </Button>
        </form>
      </div>
    </div>
  );
};

export default Survey;
