module Spree
  class Calculator::SimpleWeight < Spree::Calculator
    preference :costs_string, :text, :default => "1:5\n2:7\n5:10\n10:15\n100:50"
    preference :default_weight, :decimal, :default => 1
    preference :max_item_size, :decimal, :default => 0
    preference :handling_fee, :decimal, :default => 0
    preference :handling_max, :decimal, :default => 0

    attr_accessible :preferred_costs_string,  :preferred_max_item_size,
                    :preferred_handling_max, :preferred_handling_fee,
                    :preferred_default_weight

    def self.description
      I18n.t(:simple_weight)
    end

    def self.register
      super
    end

    def available?(order)
      return false if !costs_string_valid? || order_overweight?(order)

      if preferred_max_item_size > 0
        order.line_items.each do |item|
          return false if item_oversized?(item)
        end
      end

      true
    end

    def compute(object)
      return 0 if object.nil?
      case object
        when Spree::Order
          compute_order(object)
        when Spree::Shipment
          compute_order(object.order)
      end
    end

    private
    def clean_costs_string
      preferred_costs_string.strip
    end

    def compute_order(order)
      line_items_total = order.line_items.sum(&:total)
      handling_fee = preferred_handling_max > line_items_total ? preferred_handling_fee : 0

      total_weight = total_weight(order)
      costs = costs_string_to_hash(clean_costs_string)
      weight_class = costs.keys.select { |w| total_weight <= w }.min
      shipping_costs = costs[weight_class]

      return 0 unless shipping_costs
      shipping_costs + handling_fee
    end

    def costs_string_valid?
      !clean_costs_string.empty? &&
      clean_costs_string.count(':') > 0 &&
      clean_costs_string.split(/\:|\n/).size.even? &&
      clean_costs_string.split(/\:|\n/).all? { |s | s.strip.match(/^\d|\.+$/) }
    end

    def item_oversized?(item)
      return false if preferred_max_item_size == 0

      variant = item.variant
      sizes = [ variant.width || 0, variant.depth || 0, variant.height || 0 ]

      sizes.max > preferred_max_item_size
    end

    def order_overweight?(order)
      total_weight = total_weight(order)
      hash = costs_string_to_hash(clean_costs_string)

      total_weight > hash.keys.max
    end

    def costs_string_to_hash(costs_string)
      costs = {}
      costs_string.split.each do |cost_string|
        values = cost_string.strip.split(':')
        costs[values[0].strip.to_f] = values[1].strip.to_f
      end

      costs
    end

    def total_weight(order)
      weight = 0
      order.line_items.each do |item|
        weight += item.quantity * (item.variant.weight || preferred_default_weight)
      end

      weight
    end
  end
end