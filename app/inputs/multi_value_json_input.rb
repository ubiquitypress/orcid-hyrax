class MultiValueJsonInput < SimpleForm::Inputs::CollectionInput
  def input_type
    "multi_value"
  end

  def input(wrapper_options)
    @rendered_first_element = false

    input_html_classes.unshift('string')
    input_html_options[:name] ||= "#{object_name}[creator][#{attribute_name}][]"

    outer_wrapper do
      buffer_each(collection) do |value, index|
        inner_wrapper do
          build_field(value, index)
        end
      end
    end
  end

  protected

  def buffer_each(collection)
    collection.each_with_object('').with_index do |(value, buffer), index|
      buffer << yield(value, index)
    end
  end

  def outer_wrapper
    <<-HTML
      <ul class="listing">
        #{yield}
      </ul>
    HTML
  end

  def inner_wrapper
    <<-HTML
      <li class="field-wrapper">
        #{yield}
      </li>
    HTML
  end

  private

  def build_field(value, index)
    options = build_field_options(value, index)

    if options.delete(:type) == 'textarea'.freeze
      @builder.text_area(attribute_name, options)
    else
      @builder.text_field(attribute_name, options)
    end
  end

  # Although the 'index' parameter is not used in this implementation it is useful in an
  # an overridden version of this method, especially when the field is a complex object and
  # the override defines nested fields.
  def build_field_options(value, index)
    options = input_html_options.dup
# byebug
    options[:value] = value
    if @rendered_first_element
      options[:id] = nil
      options[:required] = nil
    else
      options[:id] ||= input_dom_id
    end

    options[:class] ||= []
    options[:class] += ["#{input_dom_id} form-control multi-text-field multi_value"]
    options[:'aria-labelledby'] = label_id
    @rendered_first_element = true

    options
  end

  def label_id
    input_dom_id + '_label'
  end

  def input_dom_id
    input_html_options[:id] || "#{object_name}_#{attribute_name}"
  end

  def collection
    @collection ||= begin
      val = object.send(attribute_name)
      col = val.respond_to?(:to_ary) ? val.to_ary : val
      col.reject { |value| value.to_s.strip.blank? } + ['']
    end
  end

  def multiple?
    true
  end
end
