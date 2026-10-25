# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  # patient identity and health text never reach a log
  :message, :full_name, :birth_date, :insurance_number, :phone, :note, :reply, :edits, :sections,
  :course, :outcome, :adherence, :recommendation
]
