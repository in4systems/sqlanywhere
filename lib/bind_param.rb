require 'ffi'

class SQLAnywhere::BindParam < FFI::Struct

  layout(
    :direction, SQLAnywhere::DataDirection,
    :value, SQLAnywhere::DataValue,
    :name, :string,
    )

  def get_name
    self[:name]
  end

  def get_direction
    self[:direction]
  end

  def inspect
    "<#{self.class} direction: #{self[:direction]}, name: #{self[:name]}, value: #{self[:value].inspect}>"
  end

  def set_value(value)

    self[:value][:is_null] = SQLAnywhere::LibC.malloc(SQLAnywhere::Bool.size)
    self[:value][:is_null].write_int(0)

    if self[:direction] == :input

      case value
      when String
        self[:value][:length] = SQLAnywhere::LibC.malloc(FFI::Type::ULONG.size)
        length = value.bytesize
        self[:value][:length].write_ulong(length)
        self[:value][:buffer] = SQLAnywhere::LibC.malloc(length + 1)

        ## Don't use put_string as that includes the terminating null
        # value.each_byte.each_with_index do |byte, index|
        #  self[:value][:buffer].put_uchar(index, byte)
        # end
        self[:value][:buffer].put_string(0, value)
        self[:value][:type] = :string

      when Fixnum
        if FFI::Type::POINTER.size == 4 # 32 bit
          self[:value][:buffer] = SQLAnywhere::LibC.malloc(FFI::Type::INT.size)
          self[:value][:type] = :val32
        else # 64 bit
          self[:value][:buffer] = SQLAnywhere::LibC.malloc(FFI::Type::LONG.size)
          self[:value][:type] = :val64
        end
        byte_array = [value].pack(self[:value][:type] == :val32 ? 'l' : 'q')
        offset = 0
        byte_array.each_byte do |b|
          self[:value][:buffer].put_char(offset, b)
          offset += 1
        end

      when Bignum
        self[:value][:buffer] = SQLAnywhere::LibC.malloc(FFI::Type::LONG_LONG.size)
        self[:value][:type] = :val64
        byte_array = [value].pack('l_')
        offset = 0
        byte_array.each_byte do |b|
          self[:value][:buffer].put_char(offset, b)
          offset += 1
        end
      when Float
        self[:value][:buffer] = SQLAnywhere::LibC.malloc(FFI::Type::DOUBLE.size)
        self[:value][:buffer].write_double(value)
        self[:value][:type] = :double
      when nil
        self[:value][:is_null].write_int(1)
        self[:value][:buffer] = SQLAnywhere::LibC.malloc(FFI::Type::INT.size)
        self[:value][:type] = :val32
      else
        raise "Cannot convert type (#{value.class}). Must be STRING, FIXNUM, BIGNUM, FLOAT, or NIL"
      end

    else
      self[:value][:buffer] = SQLAnywhere::LibC.malloc(
        case self[:value][:type]
        when :string
          self[:value][:buffer_size]
        when :double
          FFI::Type::FLOAT.size # Is this right? it's what the old code does
        when :val64, :uval64
          FFI::Type::LONG_LONG.size
        when :val32, :uval32
          FFI::Type::INT.size
        when :val16, :uval16
          FFI::Type::SHORT.size
        when :val8, :uval8
          FFI::Type::CHAR.size
        else
          raise "Type unknown (#{self[:value][:type]})"
        end
        )
        
    end
    nil
  end

end
