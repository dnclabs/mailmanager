require 'spec_helper'

describe MailManager::Lib do
  let(:mailmanager) { mock(MailManager) }
  let(:subject)     { MailManager::Lib.new }
  let(:fake_root)   { '/foo/bar' }
  let(:process)     { mock(Process::Status) }

  before :each do
    subject.stub(:mailmanager).and_return(mailmanager)
    mailmanager.stub(:root).and_return(fake_root)
    process.stub(:exitstatus).and_return(0)
  end

  describe "#lists" do
    it "should return all existing lists" do
      list_result = <<EOF 
3 matching mailing lists found:
        Foo - [no description available]
     BarBar - Dummy list
    Mailman - Mailman site list
EOF
      subject.stub(:run_command).with("#{fake_root}/bin/list_lists 2>&1", nil).
        and_return([list_result,process])
      subject.lists.should have(3).lists
    end
  end

  describe "#create_list" do
    it "should raise an argument error if list name is missing" do
      lambda {
        subject.create_list(:admin_email => 'foo@bar.baz', :admin_password => 'qux')
      }.should raise_error(ArgumentError)
    end
    it "should raise an argument error if list admin email is missing" do
      lambda {
        subject.create_list(:name => 'foo', :admin_password => 'qux')
      }.should raise_error(ArgumentError)
    end
    it "should raise an argument error if admin password is missing" do
      lambda {
        subject.create_list(:name => 'foo', :admin_email => 'foo@bar.baz')
      }.should raise_error(ArgumentError)
    end

    context "with valid list params" do
      let(:new_aliases) {
        ['foo:              "|/foo/bar/mail/mailman post foo"',
         'foo-admin:        "|/foo/bar/mail/mailman admin foo"',
         'foo-bounces:      "|/foo/bar/mail/mailman bounces foo"',
         'foo-confirm:      "|/foo/bar/mail/mailman confirm foo"',
         'foo-join:         "|/foo/bar/mail/mailman join foo"',
         'foo-leave:        "|/foo/bar/mail/mailman leave foo"',
         'foo-owner:        "|/foo/bar/mail/mailman owner foo"',
         'foo-request:      "|/foo/bar/mail/mailman request foo"',
         'foo-subscribe:    "|/foo/bar/mail/mailman subscribe foo"',
         'foo-unsubscribe:  "|/foo/bar/mail/mailman unsubscribe foo"']
      }
      let(:new_list_return) {
        prefix =<<EOF
To finish creating your mailing list, you must edit your /etc/aliases (or                           
equivalent) file by adding the following lines, and possibly running the                            
`newaliases' program:                                                                               
                                                                                                    
## foo mailing list                                                                                 
EOF
        prefix+new_aliases.join("\n")
      }
      let(:fake_aliases_file) { mock(File) }

      before :each do
        File.stub(:open).with('/etc/aliases', 'a').and_return(fake_aliases_file)
        subject.stub(:run_newaliases_command)
      end

      it "should create the list" do
        subject.should_receive(:run_command).
          with("#{fake_root}/bin/newlist -q \"foo\" \"foo@bar.baz\" \"qux\" 2>&1", nil).
          and_return([new_list_return,process])
        subject.create_list(:name => 'foo', :admin_email => 'foo@bar.baz',
                            :admin_password => 'qux')
      end
    end
  end

  context "with populated list" do
    let(:list) { list = mock(MailManager::List)
                 list.stub(:name).and_return('foo')
                 list }

    let(:regular_members) { ['me@here.com', 'you@there.org'] }
    let(:digest_members)  { ['them@that.net'] }

    let(:cmd) { "PYTHONPATH=#{File.expand_path('lib/mailmanager')} " +
                "/usr/bin/env python " +
                "#{fake_root}/bin/withlist -q -r listproxy.command \"foo\" " }

    describe "#regular_members" do
      it "should ask Mailman for the regular list members" do
        test_lib_method(:regular_members, :getRegularMemberKeys, regular_members)
      end
    end

    describe "#digest_members" do
      it "should ask Mailman for the digest list members" do
        test_lib_method(:digest_members, :getDigestMemberKeys, digest_members)
      end
    end

    describe "#add_member" do
      it "should ask Mailman to add the member to the list" do
        new_member = 'newb@dnc.org'
        test_lib_setter(:add_member, new_member)
      end
    end

    describe "#approved_add_member" do
      it "should ask Mailman to add the member to the list" do
        new_member = 'newb@dnc.org'
        test_lib_setter(:approved_add_member, new_member)
      end
    end

    describe "#delete_member" do
      it "should ask Mailman to delete the member from the list" do
        former_member = 'oldie@ofa.org'
        test_lib_setter(:delete_member, former_member)
      end
    end

    describe "#approved_delete_member" do
      it "should ask Mailman to delete the member from the list" do
        former_member = 'oldie@ofa.org'
        test_lib_setter(:approved_delete_member, former_member)
      end
    end

    describe "#moderators" do
      it "should ask Mailman for the list's moderators" do
        test_lib_method(:moderators, :moderator, ['phb@bigcorp.com', 'nhb@smallstartup.com'])
      end
    end

    describe "#add_moderator" do
      it "should ask Mailman to add the moderator to the list" do
        subject.should_receive(:moderators).with(list).and_return({'result' => 'success', 'return' => []})
        test_lib_method(:add_moderator, 'moderator.append', nil, 'foo@bar.com')
      end

      it "should return 'already_a_moderator' if they already a moderator" do
        result = {'result' => 'already_a_moderator'}
        subject.should_receive(:moderators).with(list).and_return({'result' => 'success', 'return' => ['foo@bar.com']})
        subject.add_moderator(list, 'foo@bar.com').should == result
      end
    end

    describe "#delete_moderator" do
      it "should ask Mailman to delete the moderator from the list" do
        subject.should_receive(:moderators).with(list).and_return({'result' => 'success', 'return' => ['foo@bar.com']})
        test_lib_method(:delete_moderator, 'moderator.remove', nil, 'foo@bar.com')
      end

      it "should return 'not_a_moderator' if they are not already a moderator" do
        result = {'result' => 'not_a_moderator'}
        subject.should_receive(:moderators).with(list).and_return({'result' => 'success', 'return' => ['other@bar.com']})
        subject.delete_moderator(list, 'foo@bar.com').should == result
      end
    end

    describe "#web_page_url" do
      it "should ask Mailman for the list's web address" do
        test_lib_attr(:web_page_url, "http://bar.com/mailman/listinfo/foo")
      end
    end

    describe "#request_email" do
      it "should ask Mailman for the request email address" do
        test_lib_getter(:request_email, "foo-request@bar.com")
      end
    end

    describe "#description" do
      it "should ask Mailman for the list's description" do
        test_lib_attr(:description, "this is a mailing list")
      end
    end
  end

  def test_lib_getter(lib_method, return_value, *args)
    cc_mailman_method = camel_case("get_#{lib_method.to_s}")
    test_lib_method(lib_method, cc_mailman_method, return_value, *args)
  end

  def test_lib_setter(lib_method, *args)
    cc_mailman_method = camel_case(lib_method.to_s)
    test_lib_method(lib_method, cc_mailman_method, nil, *args)
  end

  def test_lib_attr(lib_attr, return_value)
    test_lib_method(lib_attr, lib_attr, return_value)
  end

  def test_lib_method(lib_method, mailman_method, return_value=nil, *args)
    if return_value.is_a?(Hash)
      result = return_value
    else
      result = {"result" => "success"}
      result["return"] = return_value unless return_value.nil?
    end
    subject.should_receive(:run_command).
      with(cmd+"#{mailman_method.to_s} #{cmd_args(*args)}2>&1", nil).
      and_return([JSON.generate(result),process])
    subject.send(lib_method, list, *args).should == result
  end

  def camel_case(s)
    s.gsub(/^[a-z]|[\s_]+[a-z]/) { |a| a.upcase }.gsub(/[\s_]/, '')
  end

  def cmd_args(*args)
    arg_str = args.map { |a|
      MailManager::Lib::escape(a)
    }.join(' ')
    arg_str += ' ' if arg_str.length > 0
  end
end
