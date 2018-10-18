# Controller

class PeopleController < ActionController::Base

  # ... Other REST actions

  def create
    @person = Person.new(person_params)

    if @person.save
      Email.validate_email(@person).deliver_now
      @admins = Person.where(:admin => true)
      Email.admin_new_user(@admins, @person).deliver_now unless empty?
      redirect_to @person, :notice => "Account added!"
    else
      render :new
    end
  end

  def validate_email
    @user = Person.find_by_slug(params[:slug])
    if @user.present?
      @user.validated = true
      @user.save
      Rails.logger.info "USER: User ##{@person.id} validated email successfully."
      @admins = Person.where(:admin => true)
      Email.admin_user_validated(@admins, @user).deliver_now unless empty?
      Email.welcome(@user).deliver_now
    else
      Rails.logger.info "USER: User ##{@person.id} email validation failed."
    end
  end

  private
  def person_params
    params.require(:person).permit(:first_name, :last_name, :email)
  end

end


# Model

class Person < ActiveRecord::Base
  attr_accessor :admin, :slug, :validated, :handle, :team
  before_create :set_slug, :set_team,
                :set_is_admin

  def set_slug
    self.slug = "ABC123#{Time.now.to_i}1239827#{rand(10000)}"
  end

  def set_is_admin
    self.admin = false
  end

  def set_team
    person_count = (Person.count + 1)
    team = (person_count.odd?) ? "UnicornRainbows" : "LaserScorpions"
    self.team = team
    self.handle = "#{team}#{person_count}"
  end

end


# Mailer

class Email < ActionMailer::Base

  default from: 'foo@example.com'

  def welcome(person)
    @person = person
    mail(to: @person)
  end

  def validate_email(person)
    @person = person
    mail(to: @person)
  end

  def admin_user_validated(admins, user)
    @admins = admins.collect {|a| a.email } rescue []
    @user = user
    mail(to: @admins)
  end

  def admin_new_user(admins, user)
    @admins = admins.collect {|a| a.email } rescue []
    @user = user
    mail(to: @admins)
  end

  def admin_removing_unvalidated_users(admins, users)
    @admins = admins.collect {|a| a.email } rescue []
    @users = users
    mail(to: @admins)
  end

end


# Rake Task

namespace :accounts do

  desc "Remove accounts where the email was never validated and it is over 30 days old"
  task :remove_unvalidated do
    @people = Person.where('created_at > ?', 30.days.ago).where(:validated => false)
    @people.each do |person|
      Rails.logger.info "Removing unvalidated user #{person.email}"
      person.destroy
    end
    Email.admin_removing_unvalidated_users(Person.where(:admin => true), @people).deliver_now unless empty?
  end

end
