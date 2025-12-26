import { useState, useEffect } from 'react';
import { format } from 'date-fns';
import { Calendar as CalendarIcon, Clock } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Calendar } from '@/components/ui/calendar';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { CartItem } from '@/lib/types';
import { updateServiceBooking } from '@/lib/cart';
import { cn } from '@/lib/utils';

interface ServicePickerProps {
  item: CartItem;
  onUpdate: () => void;
}

const timeSlots = [
  '09:00', '09:30', '10:00', '10:30', '11:00', '11:30',
  '12:00', '12:30', '13:00', '13:30', '14:00', '14:30',
  '15:00', '15:30', '16:00', '16:30', '17:00'
];

export function ServicePicker({ item, onUpdate }: ServicePickerProps) {
  const [date, setDate] = useState<Date | undefined>(
    item.serviceDate ? new Date(item.serviceDate) : undefined
  );
  const [time, setTime] = useState<string>(item.serviceTime || '');

  useEffect(() => {
    if (date && time) {
      updateServiceBooking(item.id, format(date, 'yyyy-MM-dd'), time);
      onUpdate();
    }
  }, [date, time, item.id, onUpdate]);

  return (
    <div className="p-4 bg-accent/50 rounded-xl border border-border mt-2">
      <div className="flex items-center gap-2 mb-4">
        <div className="w-8 h-8 rounded-lg bg-service/10 flex items-center justify-center">
          <CalendarIcon className="w-4 h-4 text-service" />
        </div>
        <div>
          <h4 className="font-medium text-sm">Book Your Session</h4>
          <p className="text-xs text-muted-foreground">{item.name} • {item.duration} min</p>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        {/* Date Picker */}
        <Popover>
          <PopoverTrigger asChild>
            <Button
              variant="outline"
              className={cn(
                "justify-start text-left font-normal",
                !date && "text-muted-foreground"
              )}
            >
              <CalendarIcon className="mr-2 h-4 w-4" />
              {date ? format(date, "PPP") : "Select date"}
            </Button>
          </PopoverTrigger>
          <PopoverContent className="w-auto p-0" align="start">
            <Calendar
              mode="single"
              selected={date}
              onSelect={setDate}
              disabled={(date) => date < new Date() || date.getDay() === 0}
              initialFocus
              className="pointer-events-auto"
            />
          </PopoverContent>
        </Popover>

        {/* Time Picker */}
        <Select value={time} onValueChange={setTime}>
          <SelectTrigger className={cn(!time && "text-muted-foreground")}>
            <Clock className="mr-2 h-4 w-4" />
            <SelectValue placeholder="Select time" />
          </SelectTrigger>
          <SelectContent>
            {timeSlots.map(slot => (
              <SelectItem key={slot} value={slot}>
                {slot}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {date && time && (
        <div className="mt-3 p-2 bg-service/10 rounded-lg text-sm text-service font-medium flex items-center gap-2">
          <CalendarIcon className="w-4 h-4" />
          Booked: {format(date, "MMMM d, yyyy")} at {time}
        </div>
      )}
    </div>
  );
}
