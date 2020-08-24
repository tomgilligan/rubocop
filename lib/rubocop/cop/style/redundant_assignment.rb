# frozen_string_literal: true

module RuboCop
  module Cop
    module Style
      # This cop checks for redundant assignment before returning.
      #
      # @example
      #   # bad
      #   def test
      #     x = foo
      #     x
      #   end
      #
      #   # bad
      #   def test
      #     if x
      #       z = foo
      #       z
      #     elsif y
      #       z = bar
      #       z
      #     end
      #   end
      #
      #   # good
      #   def test
      #     foo
      #   end
      #
      #   # good
      #   def test
      #     if x
      #       foo
      #     elsif y
      #       bar
      #     end
      #   end
      #
      # @api private
      class RedundantAssignment < Base
        extend AutoCorrector

        MSG = 'Redundant assignment before returning detected.'

        def_node_matcher :redundant_assignment?, <<~PATTERN
          (... $(lvasgn _name _expression) (lvar _name))
        PATTERN

        def on_def(node)
          check_branch(node.body)
        end
        alias on_defs on_def

        private

        def check_branch(node)
          return unless node

          case node.type
          when :case   then check_case_node(node)
          when :if     then check_if_node(node)
          when :rescue, :resbody
            check_rescue_node(node)
          when :ensure then check_ensure_node(node)
          when :begin, :kwbegin
            check_begin_node(node)
          end
        end

        def check_case_node(node)
          node.when_branches.each { |when_node| check_branch(when_node.body) }
          check_branch(node.else_branch)
        end

        def check_if_node(node)
          return if node.modifier_form? || node.ternary?

          check_branch(node.if_branch)
          check_branch(node.else_branch)
        end

        def check_rescue_node(node)
          node.child_nodes.each do |child_node|
            check_branch(child_node)
          end
        end

        def check_ensure_node(node)
          check_branch(node.body)
        end

        def check_begin_node(node)
          if (assignment = redundant_assignment?(node))
            add_offense(assignment) do |corrector|
              expression = assignment.children[1]
              corrector.replace(assignment, expression.source)
              corrector.remove(right_sibling_of(assignment))
            end
          else
            last_expr = node.children.last
            check_branch(last_expr)
          end
        end

        def right_sibling_of(node)
          siblings_of(node)[node.sibling_index + 1]
        end

        def siblings_of(node)
          node.parent.children
        end
      end
    end
  end
end
