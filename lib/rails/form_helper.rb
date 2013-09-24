module AwesomeNestedFields
  module ActionViewExtensions
    module Builder
      def nested_fields_for(record_name, record_object=nil, **options, &block)
        raise ArgumentError, 'Missing block to nested_fields_for' unless block_given?

        association = record_name

        options[:new_item_index] ||= 'new_nested_item'
        options[:new_object] ||= self.object.class.reflect_on_association(association).klass.new
        options[:item_template_class] ||= ['template', 'item', association.to_s.singularize].join(' ')
        options[:empty_template_class] ||= ['template', 'empty', association.to_s.singularize].join(' ')
        options[:show_empty] ||= false
        options[:render_template] = options.key?(:render_template) ? options[:render_template] : true
        options[:escape_template] = options.key?(:escape_template) ? options[:escape_template] : true

        output = @template.capture { simple_fields_for(record_name, record_object, options.except(:new_item_index, :new_object, :item_template_class, :empty_template_class, :show_empty, :render_template, :escape_template), &block) }
        output ||= template.raw ""

        if options[:show_empty] and self.object.send(association).empty?
          output.safe_concat @template.capture { yield nil }
        end

        template = render_nested_fields_template(association, options, &block)
        if options[:render_template]
          output.safe_concat template
        else
          add_nested_fields_template(association, template)
        end

        output
      end

    protected

      def render_nested_fields_template(association, options, &block)
        templates = @template.content_tag(:script, :type => 'text/html', :class => options[:item_template_class]) do
          template = simple_fields_for(association, options[:new_object], options.merge({child_index: options[:new_item_index]}).except(:new_item_index, :new_object, :item_template_class, :empty_template_class, :show_empty, :render_template, :escape_template), &block)
          template = AwesomeNestedFields.escape_html_tags(template) if options[:escape_template]
          template
        end

        if options[:show_empty]
          empty_template = @template.content_tag(:script, :type => 'text/html', :class => options[:empty_template_class]) do
            template = @template.capture { yield nil }
            template = AwesomeNestedFields.escape_html_tags(template) if options[:escape_template]
            template
          end
          templates.safe_concat empty_template
        end

        templates
      end

      def add_nested_fields_template(association, template)
        # It must be a hash, so we don't get repeated templates on deeply nested models
        @template.instance_variable_set(:@nested_fields_template_cache, {}) unless @template.instance_variable_get(:@nested_fields_template_cache)
        @template.instance_variable_get(:@nested_fields_template_cache)[association] = template
        create_nested_fields_template_helper!
      end

      def create_nested_fields_template_helper!
        def @template.nested_fields_templates
          @nested_fields_template_cache.reduce(ActiveSupport::SafeBuffer.new) do |buffer, entry|
            association, template = entry
            buffer.safe_concat template
          end
        end unless @template.respond_to?(:nested_fields_templates)
      end
    end
  end
end

module ActionView::Helpers
  class FormBuilder
    include AwesomeNestedFields::ActionViewExtensions::Builder
  end
end
