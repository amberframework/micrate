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
end

def sample_migrations
  {
    20160523142308 => true,
    20160523142313 => true,
    20160523142316 => true,
  }
end
