class Token < Struct.new(:type,:value)
	def to_s
		return "#{@type}, #{@value}"
	end
end

class Tokenizer
	def self.tokenize(str)
		tokens = str.gsub("(", " ( ").gsub(")", " ) ").split.map do |t|
			case t 
			when "(" then Token.new(:lparen, t)
			when ")" then Token.new(:rparen, t)
			when "'" then Token.new(:quote, t)
			when "if" then Token.new(:if, t)
			when /^\d+$/ then Token.new(:number, t.to_i)
			when /^[\w\+\-\/\*]+[\d_]*$/ then Token.new(:symbol, t)
		else
				puts "Invalid symbol : #{t}" 
			end
		end

		return TokenStream.new(tokens)
	end
end

class TokenStream 
	attr_accessor :tokens, :index

	def initialize(tokens)
		@@tokens = tokens
		@index = 0
	end

	def current
		@@tokens[@index]
	end

	def next
		@@tokens[@index+1]
	end

	def next_token
		@index += 1
	end
	def expect(t)
		if t != current.type 
			puts "unexpected token, expected #{t.to_s} but got #{current.type.to_s}" 
			return false
		else
			return true
		end
	end
	def next_if_expected(t)
		next_token if expect(t)
	end
end

class ValueExpression < Struct.new(:value);end
class FunctionExpression < Struct.new(:name, :args);end
class IfElseExpression < Struct.new(:cond, :left, :right);end
class Program < Struct.new(:expressions);end

class Parser
	attr_reader :token_stream

	def initialize(stream)
		@token_stream = stream
	end

	def token_stream=(stream)
		@token_stream = stream
	end

	
	def parse
		exprs = []
		until @token_stream.current == nil
			exprs << parse_expr
		end
		return Program.new(exprs)
	end

	def parse_expr
		case @token_stream.current.type
		when :quote, :number, :symbol then return parse_value
		when :lparen 
			return parse_if_expression if @token_stream.next.type == :if
			return parse_function_call if @token_stream.next.type == :symbol
		end
	end

	def parse_atom
		value = @token_stream.current.value
		@token_stream.next_token
		return ValueExpression.new(value)
	end

	def parse_list
		@token_stream.next_if_expected(:quote)
		@token_stream.next_if_expected(:lparen)
		args = []
		until @token_stream.current.type == :rparen do 
			args << @token_stream.current.value
			@token_stream.next_token
		end

		@token_stream.next_token

		return ValueExpression.new(args)
	end
		
	def parse_value
		case @token_stream.current.type
		when :quote then return parse_list
		when :number, :symbol then return parse_atom
		end
	end

	def parse_function_call
		@token_stream.next_if_expected(:lparen)
		@token_stream.expect(:symbol)
		name = @token_stream.current.value
		@token_stream.next_token
		args = []
		until @token_stream.current.type == :rparen 
			args << parse_expr
		end

		@token_stream.next_token
		return FunctionExpression.new(name,args)
	end

	def parse_if_expression
		@token_stream.next_if_expected(:lparen)
		@token_stream.next_if_expected(:if)
		cond = parse_expr
		left = parse_expr
		right = parse_expr
		@token_stream.next_token
		return IfElseExpression.new(cond,left,right)
	end
end

class Evaluator
	attr_accessor :environment

	def initialize
		@environment = {
			'print' => ->x{puts x},
			'+' => ->x{x.reduce(:+)},
			'-' => ->x{x.reduce(:-)},
			'*' => ->x{x.reduce(:*)},
			'/' => ->x{x.reduce(:div)},
		}
	end

	def eval_expression(expression)
		case expression
		in ValueExpression 
			if @environment.include? expression.value
				@environment[expression.value]
			else
				expression.value
			end
		in FunctionExpression 
			case expression.name 
			when "def" 
				k = eval_expression(expression.args[0])
				v = eval_expression(expression.args[1])
				@environment[k]=v
			else @environment[expression.name].call(expression.args.map{|a| eval_expression a})
			end
		in IfElseExpression 
			if(eval_expression(expression.cond) != 0) 
				eval_expression(expression.left) 
			else eval_expression(expression.right) 
			end
		end
	end
end

def eval_program(prog)
	evaluator = Evaluator.new
	prog.expressions.each {|expr| evaluator.eval_expression(expr)}
end

def run_repl
	parser = Parser.new(nil)
	loop do 
		tokens = Tokenizer.tokenize(gets.chomp)
		parser.token_stream = tokens
		ast = parser.parse
		eval_program(ast)
	end
end

def run_file(path)
	eval_program(Parser.new(Tokenizer.tokenize(File.read(path))).parse)
end

if __FILE__==$0
	if ARGV.empty?
		run_repl
	else
		run_file(ARGV[0])
	end
end