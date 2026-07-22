import { CredentialsService } from '../services/credentials.js'

class CredentialsController {
  constructor(credentialsService = new CredentialsService()) {
    this.credentialsService = credentialsService
  }

  async getCredentials(req, res, next) {
    try {
      const credentials = await this.credentialsService.getCredentials(req.params.profile)
      res.setHeader('Cache-Control', 'no-store')
      res.setHeader('Pragma', 'no-cache')
      res.json(credentials)
    }
    catch (error) {
      next(error)
    }
  }
}

let controller
const credentialsController = (req, res, next) => {
  controller ||= new CredentialsController()
  return controller.getCredentials(req, res, next)
}

export { credentialsController, CredentialsController }
