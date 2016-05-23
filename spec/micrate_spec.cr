require "./spec_helper"

describe Micrate do

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

end
