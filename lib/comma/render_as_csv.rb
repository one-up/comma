module RenderAsCSV
  def self.included(base)
    base.alias_method_chain :render, :csv
  end

  def render_with_csv(options = nil, extra_options = {}, &block)
    return render_without_csv(options, extra_options, &block) unless options.is_a?(Hash) and options[:csv].present?

    content  = options.delete(:csv)
    style    = options.delete(:style) || :default
    filename = options.delete(:filename)
    encoding = options.delete(:encoding) || 'utf-8'

    headers.merge!(
      'Content-Transfer-Encoding' => 'binary',
      'Content-Type'              => "text/csv; charset=#{encoding}"
    )
    filename_header_value = "attachment"
    filename_header_value += "; filename=\"#{filename}\"" if filename.present?
    headers.merge!('Content-Disposition' => filename_header_value)

    @performed_render = false

    render_stream :status => 200,
                  :content => Array(content),
                  :style => style,
                  :encoding => encoding
  end

  protected

  def render_stream(options)
    status  = options[:status]
    content = options[:content]
    style   = options[:style]
    encoding = options[:encoding]

    if Rails::VERSION::MAJOR == 3 && Rails::VERSION::MINOR == 0 # && Rails::VERSION::TINY < 4 # NOTE: not applied in rails 3.0.4
      # NOTE: temporary change until Rails 3.0.4 release ...
      # NOTE: see https://rails.lighthouseapp.com/projects/8994/tickets/4554-render-text-proc-regression
      render :status => status, :text => StringIO.new.tap {|output|
        output.write FasterCSV.generate_line(content.first.to_comma_headers(style))
        content.each { |line| output.write FasterCSV.generate_line(line.to_comma(style)) }
      }.string.encode(encoding)
    else
      # better
      render :status => status, :text => Proc.new { |response, output|
        output.write FasterCSV.generate_line(content.first.to_comma_headers(style), :encoding => encoding)
        content.each { |line| output.write FasterCSV.generate_line(line.to_comma(style), :encoding => encoding) }
      }
    end
  end
end

#credit : http://ramblingsonrails.com/download-a-large-amount-of-data-in-csv-from-rails
