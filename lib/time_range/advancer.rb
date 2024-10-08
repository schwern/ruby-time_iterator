require_relative 'time'

class TimeRange < Range
  # @private
  #
  # Logic taken from ActiveSupport to add time intervals to Time objects.
  module Advancer
    class << self
      # From rails/activesupport/lib/active_support/core_ext/time/calculations.rb
      def advance_time(time, by) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        unless by[:weeks].nil?
          by[:weeks], partial_weeks = by[:weeks].divmod(1)
          by[:days] = by.fetch(:days, 0) + (7 * partial_weeks)
        end

        unless by[:days].nil?
          by[:days], partial_days = by[:days].divmod(1)
          by[:hours] = by.fetch(:hours, 0) + (24 * partial_days)
        end

        d = advance_date(time.to_date.gregorian, by)
        time_advanced_by_date = change_time(time, { year: d.year, month: d.month, day: d.day})
        seconds_to_advance =
          by.fetch(:seconds, 0) +
          (by.fetch(:minutes, 0) * 60) +
          (by.fetch(:hours, 0) * 3600)

        return time_advanced_by_date if seconds_to_advance.zero?

        return time_advanced_by_date + seconds_to_advance
      end

      # From rails/activesupport/lib/active_support/core_ext/date/calculations.rb
      def advance_date(date, by)
        date >>= (by[:years] * 12) if by[:years]
        date >>= by[:months] if by[:months]
        date += (by[:weeks] * 7) if by[:weeks]
        date += by[:days] if by[:days]

        return date
      end

      # From rails/activesupport/lib/active_support/core_ext/time/calculations.rb
      private def change_time(time, by) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        new_year   = by.fetch(:year, time.year)
        new_month  = by.fetch(:month, time.month)
        new_day    = by.fetch(:day, time.day)
        new_hour   = by.fetch(:hour, time.hour)
        new_min    = by.fetch(:min, by[:hour] ? 0 : time.min)
        new_sec    = by.fetch(:sec, by[:hour] || by[:min] ? 0 : time.sec)
        new_offset = by.fetch(:offset, nil)

        if (new_nsec = by[:nsec])
          raise ArgumentError, "Can't change both :nsec and :usec at the same time: #{by.inspect}" if by[:usec]

          new_usec = Rational(new_nsec, 1000)
        else
          new_usec = by.fetch(:usec, by[:hour] || by[:min] || by[:sec] ? 0 : Rational(time.nsec, 1000))
        end

        raise ArgumentError, "argument out of range" if new_usec >= 1_000_000

        new_sec += Rational(new_usec, 1_000_000)

        if new_offset
          ::Time.new(new_year, new_month, new_day, new_hour, new_min, new_sec, new_offset)
        elsif time.utc?
          ::Time.utc(new_year, new_month, new_day, new_hour, new_min, new_sec)
        elsif time.zone.respond_to?(:utc_to_local)
          new_time = ::Time.new(new_year, new_month, new_day, new_hour, new_min, new_sec, time.zone)

          # When there are two occurrences of a nominal time due to DST ending,
          # `Time.new` chooses the first chronological occurrence (the one with a
          # larger UTC offset). However, for `change`, we want to choose the
          # occurrence that matches this time's UTC offset.
          #
          # If the new time's UTC offset is larger than this time's UTC offset, the
          # new time might be a first chronological occurrence. So we add the offset
          # difference to fast-forward the new time, and check if the result has the
          # desired UTC offset (i.e. is the second chronological occurrence).
          offset_difference = new_time.utc_offset - time.utc_offset
          if offset_difference.positive? && (new_time2 = new_time + offset_difference).utc_offset == time.utc_offset
            new_time2
          else
            new_time
          end
        elsif time.zone
          ::Time.local(new_sec, new_min, new_hour, new_day, new_month, new_year, nil, nil, time.isdst, nil)
        else
          ::Time.new(new_year, new_month, new_day, new_hour, new_min, new_sec, time.utc_offset)
        end
      end
    end
  end
end
