require "./spec_helper"

Spectator.describe Micrate::Cli do
  # mock File do
  #   stub self.delete(path : Path | String) { nil }
  # end

  # mock Micrate::DB do
  #   stub self.connect() { nil }
  # end

  # describe "#drop_database" do
  #   context "sqlite3" do
  #     it "deletes the file" do
  #       Micrate::DB.connection_url = "sqlite3:myfile"
  #       Micrate::Cli.drop_database
  #       expect(File).to have_received(:delete).with("myfile")
  #     end
  #   end

  #   context "postgres" do
  #     it "calls drop database" do
  #       Micrate::DB.connection_url = "postgres://user:pswd@host:5432/database"
  #       Micrate::Cli.drop_database
  #       expect(Micrate::DB).to have_received(:connect)
  #     end
  #   end
  # end

  # describe "#create_database" do
  #   context "sqlite3" do
  #     it "doesn't call connect" do
  #       Micrate::DB.connection_url = "sqlite3:myfile"
  #       Micrate::Cli.create_database
  #       expect(Micrate::DB).not_to have_received(:connect)
  #     end
  #   end

  #   context "postgres" do
  #     it "calls connect" do
  #       Micrate::DB.connection_url = "postgres://user:pswd@host:5432/database"
  #       Micrate::Cli.create_database
  #       expect(Micrate::DB).to have_received(:connect)
  #     end
  #   end
  # end
end
