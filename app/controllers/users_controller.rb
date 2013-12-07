require 'rubygems'
require 'json'
require 'digest/md5'

class UsersController < ApplicationController
  before_filter :signed_in_user, only: [:show, :ip]

  def ip
    @user = User.find(session[:user_id])
    if params[:ip].blank?
      if !@user.secure_ip.nil?
        iptables_remove_ip @user.secure_ip
        @user.secure_ip = nil;
        @user.save!(validate: false)
        flash[:success] = "Your ZNC server is now accessible by anyone."
      end
    else
      if !check_ip(params[:ip])
        flash[:error] = "Wrong IP format"
      else
        if !@user.secure_ip.nil?
          iptables_remove_ip(@user.secure_ip)
        end
        iptables_add_ip(params[:ip])
        @user.secure_ip = params[:ip]
        @user.save(validate: false)
        flash[:success] = "Your ZNC server will now work only with requests from IP #{@user.secure_ip}."
      end
    end
    redirect_to me_path
  end

  def index
    redirect_to root_path
  end

  def new
    @user = User.new
  end

  def show
    @user = current_user
    @md5 = digest = Digest::MD5.hexdigest(@user.email)[0...11]
  end

  def create
    @user = User.new(params[:user])
    @user.secure_ip = nil;
    create_znc_instance
    if @user.save
      sign_in @user
      flash[:success] = "Welcome!"
      redirect_to me_path
    else
      render 'new'
    end
  end
  
  private

  def signed_in_user
    unless signed_in?
      store_location
      redirect_to signin_url, notice: "Please sign in."
    end
  end

  def create_znc_instance
    docker_cmd = ENV['docker_cmd'] ||= 'docker'
    container_id = `#{docker_cmd} run -e ZNC_USER=#{@user.znc_user} -e ZNC_PASS=#{@user.znc_pass} -d -p 6667 -u znc paulczar/znc start-znc`
    cmd = "#{docker_cmd} inspect #{container_id}"
    json_infos = `#{cmd}`
    i = JSON.parse(json_infos)
    @user.port = i[0]["NetworkSettings"]["Ports"]["6667/tcp"]["HostPort"]
    @user.container_id = container_id
    @user.docker_ip = i[0]["NetworkSettings"]["IpAddress"]
    sleep 2
    @user.log = `#{docker_cmd} logs #{container_id}`
  end
  
  $VALIDATE_IP_REGEX = /^([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])$/  
  def check_ip(i)
    if ($VALIDATE_IP_REGEX.match(i))
      return true;
    end
    return false;
  end
  
  def iptables_add_ip(i)
    cwd = Dir.pwd
    `sudo #{cwd}/iptables/add_ip #{@user.docker_ip} #{i}`
  end

  def iptables_remove_ip(i)
    cwd = Dir.pwd
    `sudo #{cwd}/iptables/remove_ip #{@user.docker_ip} #{i}`
  end

end
