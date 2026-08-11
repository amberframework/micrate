require "./spec_helper"

Spectator.describe Micrate do
  describe "dbversion" do
    it "returns 0 if table is empty" do
      rows = [] of {Int64, Bool}
      Micrate.extract_dbversion(rows).should eq(0)
    end

    it "returns last applied migration" do
      # expect rows to be order by id asc
      rows = [
        {20160101140000, true},
        {20160101130000, true},
        {20160101120000, true},
      ] of {Int64, Bool}

      Micrate.extract_dbversion(rows).should eq(20160101140000)
    end

    it "ignores rolled back versions" do
      rows = [
        {20160101140000, false},
        {20160101140000, true},
        {20160101120000, true},
      ] of {Int64, Bool}

      Micrate.extract_dbversion(rows).should eq(20160101120000)
    end
  end

  describe "up" do
    context "going forward" do
      it "runs all migrations if starting from clean db" do
        plan = Micrate.migration_plan(sample_migrations, 0, 20160523142316, :forward)
        plan.should eq([20160523142308, 20160523142313, 20160523142316])
      end

      it "skips already performed migrations" do
        plan = Micrate.migration_plan(sample_migrations, 20160523142308, 20160523142316, :forward)
        plan.should eq([20160523142313, 20160523142316])
      end
    end

    context "going backwards" do
      it "skips already performed migrations" do
        plan = Micrate.migration_plan(sample_migrations, 20160523142316, 20160523142308, :backwards)
        plan.should eq([20160523142316, 20160523142313])
      end
    end

    context "with mixed timestamp precision" do
      it "orders Amber millisecond and historic Micrate second timestamps chronologically" do
        migrations = {
             20220906195432 => false,
          20220907021800909 => false,
             20220908100000 => false,
        }

        plan = Micrate.migration_plan(migrations, 0, 20220908100000, :forward)
        plan.should eq([20220906195432, 20220907021800909, 20220908100000])
      end

      it "detects a genuinely older migration without treating all 14-digit versions as old" do
        migrations = {
             20220906195432 => false,
          20220907021800909 => true,
             20220908100000 => false,
        }

        expect_raises(Micrate::UnorderedMigrationsException) do
          Micrate.migration_plan(migrations, 20220907021800909, 20220908100000, :forward)
        end
      end
    end

    describe "detecting unordered migrations" do
      it "fails if there are unapplied migrations with older timestamp than current version" do
        migrations = {
          20160523142308 => false,
          20160523142313 => true,
          20160523142316 => false,
        }

        expect_raises(Micrate::UnorderedMigrationsException) do
          Micrate.migration_plan(migrations, 20160523142313, 20160523142316, :forward)
        end
      end
    end
  end

  describe "create" do
    it "uses Amber-compatible millisecond timestamps" do
      root = File.join(Dir.tempdir, "micrate-create-#{Process.pid}-#{Random.rand(1_000_000)}")
      begin
        path = Micrate.create("create_pets", root, Time.utc(2026, 8, 11, 12, 34, 56, nanosecond: 789_000_000))
        File.basename(path).should eq("20260811123456789_create_pets.sql")
      ensure
        FileUtils.rm_r(root) if Dir.exists?(root)
      end
    end
  end
end

def sample_migrations
  {
    20160523142308 => true,
    20160523142313 => true,
    20160523142316 => true,
  }
end
