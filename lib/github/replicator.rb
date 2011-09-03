module GitHub
  module Replicator
    # Dumps replicants in a streaming fashion.
    #
    # The Dumper takes an ActiveRecord object and generates one or more replicant
    # objects. A replicant object has the form: [type, id, attributes] and
    # describes exactly one record in the database. The type and id identify the
    # record's model class name string and primary key id, respectively. The
    # attributes is a Hash of primitive typed objects generated by a call to
    # ActiveRecord::Base#attributes.
    #
    # Dumping to an array:
    #
    #     >> replicator = Replicator::Dumper.new
    #     >> replicator.dump_repository User / :defunkt / :github
    #     >> pp replicator.to_a
    #
    # Dumping to stdout in marshal format:
    #
    #     >> writer = lambda { |*a| Marshal.dump(a, $stdout) }
    #     >> replicator = Replicator::Dumper.new(&writer)
    #     >> replicator.dump_repository User / :defunkt / :github
    #
    class Dumper
      def initialize(&write)
        @objects = []
        @write = write || lambda { |type,id,att| @objects << [type,id,att] }
        @memo = {}
      end

      # Grab dumped objects array. Always empty when a custom write function was
      # provided when initialized.
      def to_a
        @objects
      end

      # Check if object has been dumped yet.
      def dumped?(object)
        @memo["#{object.class}:#{object.id}"]
      end

      # Call the write method given in the initializer or write to the internal
      # objects array when no write method was given.
      #
      # type       - The model class name as a String.
      # id         - The record's id. Usually an integer.
      # attributes - All model attributes.
      #
      # Returns nothing.
      def write(type, id, attributes)
        @write.call(type, id, attributes)
      end

      # Dump one or more objects to the internal array or provided dump
      # stream. This method guarantees that the same object will not be dumped
      # more than once.
      #
      # objects - ActiveRecord object instances.
      #
      # Returns nothing.
      def dump(*objects)
        objects = objects[0] if objects.size == 1 && objects[0].is_a?(Array)
        objects.each do |object|
          next if object.nil?
          next if dumped?(object)

          meth = "dump_#{object.class.to_s.underscore}"
          if respond_to?(meth)
            send meth, object
          else
            dump_object object
          end
        end
      end

      # Low level dump method. Generates a call to write with the attributes of
      # the given objects. This method is used in dumpspecs when dumping the
      # dumpspec's subject.
      def dump_object(object)
        return if dumped?(object)
        @memo["#{object.class}:#{object.id}"] = object
        write object.class.name, object.id, object.attributes
      end

      ##
      # Dumpspecs

      def dump_repository(repository)
        dump repository.owner
        dump repository.plan_owner
        dump_object repository
        dump repository.issues
      end

      def dump_user(user)
        dump_object user
        dump user.profile
        dump user.emails
      end

      def dump_issue(issue)
        dump issue.repository
        dump issue.user
        dump issue.assignee
        dump issue.milestone
        dump issue.pull_request
        dump_object issue
        dump issue.comments
      end

      def dump_issue_comment(comment)
        dump comment.user
        dump comment.repository
        dump_object comment
      end

      def dump_pull_request(pull)
        dump pull.repository
        dump pull.head_repository
        dump pull.base_repository
        dump pull.user
        dump pull.base_user
        dump pull.head_user
        dump_object pull
        dump pull.review_comments
      end

      def dump_pull_request_review_comment(comment)
        dump comment.user
        dump comment.pull_request
        dump_object comment
      end
    end

    class Loader
    end
  end
end
