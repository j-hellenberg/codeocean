class RequestForCommentsController < ApplicationController
  include SubmissionScoring
  before_action :set_request_for_comment, only: [:show, :edit, :update, :destroy, :mark_as_solved, :set_thank_you_note]
  before_action :set_study_group_grouping, only: %i[index get_my_comment_requests get_rfcs_with_my_comments]

  before_action :require_user!

  def authorize!
    authorize(@request_for_comments || @request_for_comment)
  end
  private :authorize!

  # GET /request_for_comments
  # GET /request_for_comments.json
  def index
    @search = RequestForComment
                  .last_per_user(2)
                  .with_last_activity
                  .ransack(params[:q])
    @request_for_comments = @search.result
                                .joins(:exercise)
                                .where(exercises: {unpublished: false})
                                .includes(submission: [:study_group])
                                .order('created_at DESC')
                                .paginate(page: params[:page], total_entries: @search.result.length)

    authorize!
  end

  # GET /my_request_for_comments
  def get_my_comment_requests
    @search = RequestForComment
                  .with_last_activity
                  .where(user: current_user)
                  .ransack(params[:q])
    @request_for_comments = @search.result
                                .order('created_at DESC')
                                .paginate(page: params[:page])
    authorize!
    render 'index'
  end

  # GET /my_rfc_activity
  def get_rfcs_with_my_comments
    @search = RequestForComment
                  .with_last_activity
                  .joins(:comments) # we don't need to outer join here, because we know the user has commented on these
                  .where(comments: {user_id: current_user.id})
                  .ransack(params[:q])
    @request_for_comments = @search.result
                                .order('last_comment DESC')
                                .paginate(page: params[:page])
    authorize!
    render 'index'
  end

  # GET /request_for_comments/1/mark_as_solved
  def mark_as_solved
    authorize!
    @request_for_comment.solved = true
    respond_to do |format|
      if @request_for_comment.save
        format.json { render :show, status: :ok, location: @request_for_comment }
      else
        format.json { render json: @request_for_comment.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /request_for_comments/1/set_thank_you_note
  def set_thank_you_note
    authorize!
    @request_for_comment.thank_you_note = params[:note]

    commenters = @request_for_comment.commenters
    commenters.each {|commenter| UserMailer.send_thank_you_note(@request_for_comment, commenter).deliver_now}

    respond_to do |format|
      if @request_for_comment.save
        format.json { render :show, status: :ok, location: @request_for_comment }
      else
        format.json { render json: @request_for_comment.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /request_for_comments/1
  # GET /request_for_comments/1.json
  def show
    authorize!
  end

  # POST /request_for_comments.json
  def create
    # Consider all requests as JSON
    request.format = 'json'
    raise Pundit::NotAuthorizedError if @embed_options[:disable_rfc]

    @request_for_comment = RequestForComment.new(request_for_comment_params)

    respond_to do |format|
      if @request_for_comment.save
        # create thread here and execute tests. A run is triggered from the frontend and does not need to be handled here.
        Thread.new do
          score_submission(@request_for_comment.submission)
        ensure
          ActiveRecord::Base.connection_pool.release_connection
        end
        format.json { render :show, status: :created, location: @request_for_comment }
      else
        format.html { render :new }
        format.json { render json: @request_for_comment.errors, status: :unprocessable_entity }
      end
    end
    authorize!
  end

  private
    # Use callbacks to share common setup or constraints between actions.
  def set_request_for_comment
    @request_for_comment = RequestForComment.find(params[:id])
  end

    # Never trust parameters from the scary internet, only allow the white list through.
  def request_for_comment_params
    # The study_group_id might not be present in the session (e.g. for internal users), resulting in session[:study_group_id] = nil which is intended.
    params.require(:request_for_comment).permit(:exercise_id, :file_id, :question, :requested_at, :solved, :submission_id).merge(user_id: current_user.id, user_type: current_user.class.name)
  end

  # The index page requires the grouping of the study groups
  # The study groups are grouped by the current study group and other study groups of the user
  def set_study_group_grouping
    current_study_group = StudyGroup.find_by(id: session[:study_group_id])
    my_study_groups = current_user.study_groups.reject { |group| group == current_study_group }
    @study_groups_grouping = [[t('request_for_comments.index.study_groups.current'), Array(current_study_group)],
                               [t('request_for_comments.index.study_groups.my'), my_study_groups]]
  end
end
